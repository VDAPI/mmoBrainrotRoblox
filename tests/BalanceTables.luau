--!strict
-- Tables of the balance report (S83): the same code builds docs/BALANS.md (tools/balance_report.luau), the 1-20
-- fixture (tests/fixtures/balance_1_20.json) and checks it (tests/balance1_20.spec.luau), so the numbers can never
-- drift between them.
--
--   tables1_20()           the S32 report tables of levels 1-20, in report order (band "1-20")
--   tablesBand(lo, hi)     the S83 world model tables of a band 20-45 / 45-70 / 70-100 (levels lo, lo + 5, ..., hi)
--   tablesItems()          S84: items, upgrades and materials, loot and luck, monster defence 20-100 (bands
--                          "S84-items", "S84-upgrades", "S84-loot", "S84-defence"; tests/fixtures/balance_items.json)
--   tablesSkills()         S85: T-SK1..6 of the class bases and reference builds (band "S85-skills"; tests/SkillModel)
--   tablesPaths()          S86: classes and paths (band "S86-paths"; tests/SkillModel; tests/fixtures/balance_paths.json)
--   values(tables, fixtureOnly?)  flat map "title|label|column" -> number (NaN cells skipped: JSON stores them as
--                          null); fixtureOnly skips tables and rows marked fixture = false
--
-- A cell's fmt: "i" integer, "1" one decimal, "2" two decimals, "%" percent, "s" seconds (one decimal).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local B = require("./Balance")
local Bosses = require("../src/shared/Data/Bosses")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Maps = require("../src/shared/Data/Maps")
local Monsters = require("../src/shared/Data/Monsters")
local Potions = require("../src/shared/Logic/Potions")
local Rarities = require("../src/shared/Data/Rarities")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local Spawns = require("../src/shared/Data/Spawns")

local BalanceTables = {}

-- S84: low / high = the cell's target band (the report prints a value outside it in bold)
export type Cell = { key: string, value: number, fmt: string, low: number?, high: number? }
export type Row = { label: string, cells: { Cell }, fixture: boolean? }
export type Table = {
	title: string,
	note: string?,
	columns: { string },
	rows: { Row },
	band: string,
	fixture: boolean?,
}

export type Builder = {
	tables: { Table },
	section: (title: string, columns: { string }, note: string?, fixture: boolean?) -> (),
	row: (label: string, cells: { { any } }, fixture: boolean?) -> (),
}

-- Collects tables of one band; a cell's key is "title|label|column" (the column name, or its index past the end).
function BalanceTables.builder(band: string): Builder
	local tables: { Table } = {}
	local current: Table? = nil
	local self: Builder
	self = {
		tables = tables,
		section = function(title: string, columns: { string }, note: string?, fixture: boolean?)
			local t: Table =
				{ title = title, note = note, columns = columns, rows = {}, band = band, fixture = fixture }
			current = t
			table.insert(tables, t)
		end,
		row = function(label: string, cells: { { any } }, fixture: boolean?)
			local t = current :: Table
			local out: { Cell } = {}
			for i, c in cells do
				local key = `{t.title}|{label}|{t.columns[i + 1] or i}`
				table.insert(out, {
					key = key,
					value = c[1] :: number,
					fmt = (c[2] or "i") :: string,
					low = c[3] :: number?,
					high = c[4] :: number?,
				})
			end
			table.insert(t.rows, { label = label, cells = out, fixture = fixture })
		end,
	}
	return self
end

function BalanceTables.values(tables: { Table }, fixtureOnly: boolean?): { [string]: number }
	local out: { [string]: number } = {}
	for _, t in tables do
		if not (fixtureOnly and t.fixture == false) then
			for _, r in t.rows do
				if not (fixtureOnly and r.fixture == false) then
					for _, c in r.cells do
						if c.value == c.value then
							out[c.key] = c.value
						end
					end
				end
			end
		end
	end
	return out
end

-- The report tables of levels 1-20 (S32, S33), unchanged titles, labels, columns and formats.
function BalanceTables.tables1_20(): { Table }
	local tb = BalanceTables.builder("1-20")
	local section, row = tb.section, tb.row
	local LEVELS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }
	local KEY_LEVELS = { 1, 2, 5, 10, 15, 18, 20 }

	section("Gracz z ekwipunkiem na poziomie (Zwykły, ilvl = poziom − 2)", {
		"poziom",
		"Wojownik HP",
		"Wojownik DPS",
		"Łowca HP",
		"Łowca DPS",
		"Mag HP",
		"Mag DPS",
		"Kapłan HP",
		"Kapłan DPS",
	}, "DPS z 1–2 umiejętnościami (×1,2) przeciw zwykłemu potworowi tego samego poziomu.")
	for _, L in LEVELS do
		local cells = {}
		for _, c in B.CLASSES do
			local p = B.player(c, L)
			local m = B.monster(B.GENERIC, L)
			table.insert(cells, { p.values.maxHp, "i" })
			table.insert(cells, { B.dps(p, m), "i" })
		end
		row(tostring(L), cells)
	end

	section(
		"Zwykły potwór (mnożniki rodzaju 1)",
		{ "poziom", "HP", "atak", "pancerz", "EXP", "złoto", "EXP do poziomu" }
	)
	for _, L in LEVELS do
		local m = B.monster(B.GENERIC, L)
		row(tostring(L), {
			{ m.maxHp, "i" },
			{ m.attack, "1" },
			{ m.armor, "i" },
			{ B.killExp(L, B.GENERIC, L), "i" },
			{ B.killGold(L, B.GENERIC, L), "1" },
			{ Exp.expToNext(L), "i" },
		})
	end

	section("1 na 1 z potworem na poziomie gracza", {
		"poziom",
		"Wojownik s",
		"Wojownik HP",
		"Łowca s",
		"Łowca HP",
		"Mag s",
		"Mag HP",
		"Kapłan s",
		"Kapłan HP",
	}, "Cel: 6–10 s, 12–25% HP.")
	for _, L in LEVELS do
		local cells = {}
		for _, c in B.CLASSES do
			local f = B.duel(B.player(c, L), B.monster(B.GENERIC, L))
			table.insert(cells, { f.seconds, "s" })
			table.insert(cells, { f.hpLost, "%" })
		end
		row(tostring(L), cells)
	end

	section("Grupy na poziomie gracza (strata HP na całe starcie)", {
		"klasa · poziom",
		"1",
		"2",
		"3",
		"4",
		"średnio",
		"czas średnio s",
	}, "Wagi rozmiarów z `AreaSpawns`. Cel: średnio 35–60% (Mag ≤ 70%), grupa 4 ≤ 110%.")
	for _, c in B.CLASSES do
		for _, L in KEY_LEVELS do
			local g = B.expectedGroup(B.player(c, L), B.GENERIC, L)
			row(`{c} {L}`, {
				{ g.bySize[1].hpLost, "%" },
				{ g.bySize[2].hpLost, "%" },
				{ g.bySize[3].hpLost, "%" },
				{ g.bySize[4].hpLost, "%" },
				{ g.hpLost, "%" },
				{ g.seconds, "s" },
			})
		end
	end

	section("Trzy wilki na poziomie gracza (bez umiejętności)", { "klasa · poziom", "s", "HP" })
	do
		local skill = B.SKILL_DPS
		B.SKILL_DPS = 1
		for _, c in B.CLASSES do
			for _, L in { 3, 5, 6 } do
				local f = B.groupFight(B.player(c, L), B.group("wolf", L, 3))
				row(`{c} {L}`, { { f.seconds, "s" }, { f.hpLost, "%" } })
			end
		end
		B.SKILL_DPS = skill
	end

	section("Luka sprzętowa (Wojownik, przedmioty o k poziomów za nisko)", {
		"poziom",
		"k=0 s",
		"k=0 HP",
		"k=4 s",
		"k=4 HP",
		"k=9 s",
		"k=9 HP",
		"start s",
		"start HP",
	}, "Cel dla k ≤ 9: ≤ 15 s, ≤ 35% HP. „start” = tylko broń i napierśnik z poziomu 1.")
	for _, L in { 5, 10, 14, 15, 20 } do
		local cells = {}
		for _, k in { 0, 4, 9 } do
			local f = B.duel(B.player("Warrior", L, { ilvl = math.max(1, L - k) }), B.monster(B.GENERIC, L))
			table.insert(cells, { f.seconds, "s" })
			table.insert(cells, { f.hpLost, "%" })
		end
		local items = {
			{ uid = "s", id = "sword1h_1", rarity = 1, ilvl = 1, bonuses = {}, up = 0, bound = false, n = 1 },
			{ uid = "a", id = "armor_heavy_1", rarity = 1, ilvl = 1, bonuses = {}, up = 0, bound = false, n = 1 },
		}
		local f = B.duel(B.playerFromItems("Warrior", L, items), B.monster(B.GENERIC, L))
		table.insert(cells, { f.seconds, "s" })
		table.insert(cells, { f.hpLost, "%" })
		row(tostring(L), cells)
	end

	section("Elity solo (poziom spawnera = poziom gracza, +2)", {
		"klasa · poziom",
		"s",
		"HP",
	}, "Cel: 20–35 s, 60–90% HP (z miksturą wygrywa).")
	for _, c in B.CLASSES do
		for _, L in { 10, 15, 18, 20 } do
			local f = B.elite(B.player(c, L), B.GENERIC, L)
			-- S91: Elita na 20. ma poziom 22 (krzywe 20-45 S87 / S92), asertowane w balance.spec
			row(`{c} {L}`, { { f.seconds, "s" }, { f.hpLost, "%" } }, if L == 20 then false else nil)
		end
	end

	section("Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)", {
		"rodzaj · poziom spawnera",
		"solo s",
		"solo HP",
		"2 graczy s",
		"2 graczy HP",
		"3 graczy s",
		"3 graczy HP",
	}, "Cel: 2–3 graczy na poziomie. Połowa ciosów specjalnych trafia.")
	for _, spec in { { "bandit", 12 }, { "goblinScout", 16 }, { "caveSpider", 18 }, { "goblinShaman", 18 } } do
		local kind, L = spec[1] :: string, spec[2] :: number
		local pl = math.min(20, L + 2)
		local w, m, h = B.player("Warrior", pl), B.player("Mage", pl), B.player("Hunter", pl)
		local solo = B.elite2({ w }, kind, L)
		local duo = B.elite2({ w, m }, kind, L)
		local trio = B.elite2({ w, m, h }, kind, L)
		-- S91: Elita II spawnera 18 ma poziom 22 (krzywe S87 / S92), asertowane w balance.spec
		row(`{kind} {L}`, {
			{ solo.seconds, "s" },
			{ solo.hpLost, "%" },
			{ duo.seconds, "s" },
			{ duo.hpLost, "%" },
			{ trio.seconds, "s" },
			{ trio.hpLost, "%" },
		}, if L + 4 > 20 then false else nil)
	end

	section("Grimrok (poziom 20)", {
		"drużyna",
		"HP bossa",
		"walka min",
		"max cios Mag",
		"max cios Wojownik",
		"zwykły cios Mag",
		"tank HP/min",
	}, "Cel: 3–5 graczy L18–20, żaden cios > 70% HP Maga, 4–6 min. 75% czasu na biciu.")
	do
		local order = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }
		for _, n in { 1, 2, 3, 4, 5 } do
			local team = {}
			for i = 1, n do
				table.insert(team, B.player(order[i], 19))
			end
			local r = B.boss("grimrok", team)
			local mageShare, warriorShare, mageBasic = 0 / 0, r.biggest[1].share, 0 / 0
			for _, b in r.biggest do
				if b.classId == "Mage" then
					mageShare, mageBasic = b.share, b.basic
				end
			end
			if n == 1 then
				local mage = B.boss("grimrok", { B.player("Mage", 19) })
				mageShare, mageBasic = mage.biggest[1].share, mage.biggest[1].basic
			end
			row(`{n}`, {
				{ r.hp, "i" },
				{ r.seconds / 60, "1" },
				{ mageShare, "%" },
				{ warriorShare, "%" },
				{ mageBasic, "%" },
				{ r.tankHpPerMinute, "%" },
			})
		end
	end

	section("Moc przedmiotów (pełny komplet tej rzadkości vs Zwykły, ten sam ilvl)", {
		"klasa · poziom",
		"Unikatowy",
		"Heroiczny",
		"Legendarny",
		"Mityczny",
	}, "Moc = √(DPS × efektywne HP). Cel: Unikatowy +8–15%, Heroiczny +15–25%, Legendarny +25–40%.")
	for _, c in B.CLASSES do
		for _, L in { 5, 10, 20 } do
			row(`{c} {L}`, {
				{ B.rarityGain(c, L, Rarities.UNIQUE), "%" },
				{ B.rarityGain(c, L, Rarities.HEROIC), "%" },
				{ B.rarityGain(c, L, Rarities.LEGENDARY), "%" },
				{ B.rarityGain(c, L, Rarities.MYTHIC), "%" },
			})
		end
	end

	section("Broń dwuręczna vs jednoręczna + druga ręka (moc, poziom 20)", {
		"broń",
		"moc / domyślny zestaw",
	}, "Cel: ±3%.")
	do
		local pairs = {
			{ "Warrior", "sword1h", "shield" },
			{ "Warrior", "sword2h", false },
			{ "Warrior", "axe2h", false },
			{ "Warrior", "hammer2h", false },
			{ "Warrior", "spear2h", false },
			{ "Mage", "wand", "orb" },
			{ "Mage", "wand", "tome" },
			{ "Mage", "staff", false },
			{ "Mage", "runestaff", false },
			{ "Cleric", "mace1h", "shield" },
			{ "Cleric", "mace1h", "relic" },
			{ "Cleric", "holystaff", false },
		}
		local base: { [string]: number } = {}
		for _, c in B.CLASSES do
			base[c] = B.power(B.player(c, 20))
		end
		for _, spec in pairs do
			local c, w, o = spec[1] :: string, spec[2] :: string, spec[3] :: any
			local p = B.player(c, 20, { weapon = w, offhand = o })
			row(`{c} {w}{if o then " + " .. o else ""}`, { { B.power(p) / base[c], "2" } })
		end
	end

	section("Tempo (Wojownik): zabicia i czas na poziom", {
		"poziom · rodzaj",
		"EXP/zabicie",
		"zabicia",
		"s/zabicie",
		"godziny",
		"EXP/h",
		"złoto/h",
		"odpoczynek",
	}, "Grupy rodzaju z poziomu, odpoczynek z regeneracji 0,5%/s, 1 s przerwy i 6 s marszu; EXP z questów odjęty.")
	for _, L in { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 } do
		local pace = B.pace("Warrior", L)
		row(`{L} {pace.kind}`, {
			{ pace.expPerKill, "i" },
			{ pace.kills, "i" },
			{ pace.secondsPerKill, "s" },
			{ pace.hours, "2" },
			{ pace.expPerHour, "i" },
			{ pace.goldPerHour, "i" },
			{ pace.restShare, "%" },
		})
	end

	section("Złoto 1→20 (Wojownik)", {
		"poziom",
		"z zabić",
		"ze sprzedaży dropu",
		"z questów",
		"mikstury",
		"+1 broni",
		"+1…+3 broni",
		"+1…+9 broni",
	}, "Ulepszanie broni ilvl = poziom − 2, oczekiwana liczba prób (bez spadków).")
	do
		local eco = B.economy("Warrior", 20)
		for _, r in eco.rows do
			row(tostring(r.level), {
				{ r.kills, "i" },
				{ r.drops, "i" },
				{ r.pace.questGold, "i" },
				{ r.potions, "i" },
				{ r.up1, "i" },
				{ r.up3, "i" },
				{ r.up9, "i" },
			})
		end
		row("suma", {
			{ eco.killGold, "i" },
			{ eco.dropGold, "i" },
			{ eco.questGold, "i" },
			{ eco.potionGold, "i" },
			{ 0 / 0, "i" },
			{ eco.upgradeGold, "i" },
			{ 0 / 0, "i" },
		})
	end

	section("Kara złota za różnicę poziomów (gracz 20)", { "poziom potwora", "złoto", "EXP" })
	for _, L in { 10, 14, 15, 18, 20 } do
		row(tostring(L), { { B.killGold(20, B.GENERIC, L), "1" }, { B.killExp(20, B.GENERIC, L), "1" } })
	end

	section("Rodzaje Łąk: nagroda względem wytrzymałości", {
		"rodzaj",
		"mnożnik HP",
		"mnożnik ataku",
		"szybkość",
		"mnożnik nagrody",
		"EXP/s ÷ zwykły",
	}, "EXP na sekundę walki 1 na 1 (Wojownik) na środkowym poziomie rodzaju względem potwora z mnożnikami 1.")
	for _, def in Monsters.list do
		if def.region == 1 then
			local L = math.floor((def.levels.min + def.levels.max) / 2)
			local p = B.player("Warrior", L)
			local f = B.duel(p, B.monster(def, L))
			local g = B.duel(p, B.monster(B.GENERIC, L))
			row(def.id, {
				{ def.hpMul, "2" },
				{ def.atkMul, "2" },
				{ def.speed, "2" },
				{ B.kindReward(def), "2" },
				{ (B.killExp(L, def, L) / f.seconds) / (B.killExp(L, B.GENERIC, L) / g.seconds), "2" },
			})
		end
	end

	section("Drop: poziom przedmiotów i rzadkości", {
		"poziom",
		"śr. ilvl zwykłego",
		"da się założyć",
		"śr. ilvl Elity",
		"śr. ilvl Elity II",
		"zabicia (grind + questy)",
		"Unikatowe do klasy/poziom",
		"Heroiczne do klasy/h (Elity)",
	}, "Wojownik. Elity: walka + odpoczynek do pełna + marsz; Unikatowe ze zwykłych potworów z poziomu.")
	for _, L in KEY_LEVELS do
		local pace = B.pace("Warrior", L)
		local kills = pace.kills + B.questKills(L)
		-- S91: na 20. Heroiki z Elit poziomu 22 (krzywe S87 / S92), asertowane w balance.spec (wiersz 20 poza fixture)
		row(tostring(L), {
			{ B.dropIlvl(L, "normal"), "1" },
			{ B.wearableShare(L), "%" },
			{ B.dropIlvl(L, "elite"), "1" },
			{ B.dropIlvl(L, "elite2"), "1" },
			{ kills, "1" },
			{ kills * B.itemsPerKill("normal", Rarities.UNIQUE), "2" },
			{ 3600 / B.eliteCadence("Warrior", L) * B.itemsPerKill("elite", Rarities.HEROIC), "2" },
		}, if L == 20 then false else nil)
	end

	section("Elita II: przedmioty na zabicie", { "rzadkość", "na zabicie (do klasy)" })
	for _, r in { Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY } do
		row(Rarities.get(r).key, { { B.itemsPerKill("elite2", r), "2" } })
	end

	section("Ceny", { "przedmiot", "cena kupna", "wartość" })
	for _, id in
		{
			"potion_hp_1",
			"potion_hp_2",
			"potion_hp_3",
			"backpack_30",
			"backpack_45",
			"backpack_60",
			"stone_return",
			"scroll_protection",
		}
	do
		local def = Items.get(id) :: any
		if def then
			local item = {
				uid = "x",
				id = id,
				rarity = def.rarity or 1,
				ilvl = def.level,
				bonuses = {},
				up = 0,
				bound = false,
				n = 1,
			}
			row(id, { { def.buyPrice or 0, "i" }, { ItemValue.value(item :: any), "i" } })
		end
	end
	for _, L in { 5, 10, 15, 20 } do
		local def = Items.get(`sword1h_{Items.generate.tierFor(L)}`) :: any
		row(`miecz ilvl {L}`, {
			{ ItemValue.equipment(def, L, 1, 0) * ItemValue.BUY_MUL, "i" },
			{ ItemValue.equipment(def, L, 1, 0), "i" },
		})
	end

	-- S33: hunting ground profiles --------------------------------------------------------------------------------

	local PROFILE_LABELS =
		{ none = "brak", exp = "⚡ szybki exp", loot = "✦ lepszy drop", gold = "⛁ więcej złota" }

	section(
		"Expowiska z profilem: godzina expienia (Wojownik, S33)",
		{
			"poziom · profil",
			"s / zabicie",
			"EXP/h",
			"złoto/h (z dropem)",
			"monety/h",
			"przedmioty/h",
			"najlepsze/h",
		},
		"Cele (DESIGN §3.6): ⚡ ≥ 1,25× EXP/h ✦; ✦ ≥ 1,6× przedmiotów najwyższej rzadkości/h pozostałych; ⛁ ≥ 1,5× złota/h pozostałych (licząc sprzedaż dropu). Model: Logic/AreaRates (walka S32 + rozmiary grup, HP i atak profilu, odpoczynek, dojście do grupy krótsze przy szybszym respawnie)."
	)
	for _, L in { 4, 8, 12, 16, 19 } do
		for _, id in { "none", "exp", "loot", "gold" } do
			local r = B.areaRates("Warrior", L, if id == "none" then nil else id)
			row(`{L} · {PROFILE_LABELS[id]}`, {
				{ r.secondsPerKill, "s" },
				{ r.expPerHour, "i" },
				{ r.goldPerHour, "i" },
				{ r.coinGoldPerHour, "i" },
				{ r.itemsPerHour, "1" },
				{ r.topPerHour, "2" },
			})
		end
	end
	for _, L in { 30, 55, 85 } do
		for _, id in { "none", "exp", "loot", "gold" } do
			local r = B.areaRates("Warrior", L, if id == "none" then nil else id, B.GENERIC)
			row(`{L} (rodzaj 1) · {PROFILE_LABELS[id]}`, {
				{ r.secondsPerKill, "s" },
				{ r.expPerHour, "i" },
				{ r.goldPerHour, "i" },
				{ r.coinGoldPerHour, "i" },
				{ r.itemsPerHour, "1" },
				{ r.topPerHour, "2" },
			}, false)
		end
	end

	section(
		"Potwory na mapach regionów (wszystkie grupy żywe naraz, S33)",
		{ "mapa", "bez profili", "z profilami" },
		nil,
		false
	)
	for _, mapId in { "meadows", "duskwood", "ashen", "frostpeak" } do
		local data = Areas.byMap[mapId]
		local plain = table.clone(data) :: any
		plain.areas = {}
		for _, area in data.areas do
			local copy = table.clone(area) :: any
			copy.profile = nil
			table.insert(plain.areas, copy)
		end
		local function count(list: { any }): number
			local n = 0
			for _, spawner in list do
				n += spawner.count
			end
			return n
		end
		row(mapId, {
			{ count(AreaSpawns.region(plain, (Maps.get(mapId) :: any).size)), "i" },
			{ count(Spawns.byMap[mapId]), "i" },
		})
	end

	-- S91 (H3): the tables of the 1-20 retune. `fixture = false` (-- S91: <why>, asserted in balance.spec) marks the
	-- rows that depend on S92's data: fights with a monster above level 20 and the window pace at 20 and 21.
	local SkillModel = (require :: any)("./SkillModel")

	section(
		"Gracz z węzłami rzędów 1–3 (S91)",
		{
			"klasa · poziom · build",
			"1 na 1 s",
			"1 na 1 HP",
			"grupa średnio HP",
			"grupa 4 HP",
			"Elita s",
			"Elita HP",
		},
		"Gracz konwencji S32 (Zwykły, ilvl = poziom − 2, `Balance.statsFor`) z pasywkami węzłów buildu wzorcowego przyciętego do poziomu (`Balance.buildsAt`; buildy z tym samym zestawem węzłów raz). Elita tylko Wojownik, Łowca, Mag."
	)
	for _, c in B.CLASSES do
		for _, L in { 10, 15, 18, 20 } do
			for _, v in B.buildsAt(c, L) do
				if v.nodes then
					local p = B.player(c, L, { nodes = v.nodes })
					local m = B.monster(B.GENERIC, L)
					local f = B.duel(p, m)
					local g = B.expectedGroup(p, B.GENERIC, L)
					local cells: { { any } } = {
						{ f.seconds, "s" },
						{ f.hpLost, "%" },
						{ g.hpLost, "%" },
						{ g.bySize[4].hpLost, "%" },
					}
					local elite = c ~= "Cleric"
					if elite and L < 20 then
						local e = B.elite(p, B.GENERIC, L)
						table.insert(cells, { e.seconds, "s" })
						table.insert(cells, { e.hpLost, "%" })
					end
					row(`{c} {L} {v.key}`, cells)
					if elite and L == 20 then
						-- S91: Elita na 20. ma poziom 22 (krzywe 20-45 S87 / S92), asertowane w balance.spec
						local e = B.elite(p, B.GENERIC, L)
						local nan = 0 / 0
						row(`{c} {L} {v.key} (Elita, poziom 22)`, {
							{ nan, "s" },
							{ nan, "%" },
							{ nan, "%" },
							{ nan, "%" },
							{ e.seconds, "s" },
							{ e.hpLost, "%" },
						}, false)
					end
				end
			end
		end
	end

	section(
		"Tempo: model okna od 1. poziomu (S91)",
		{
			"poziom",
			"h",
			"m (średnia h z 5 poziomów)",
			"m / m − 1",
			"EXP zadań poziomu",
			"EXP przeniesione",
			"h / h − 1",
		},
		"`Balance.paceWindowAt` (Wojownik, rodzaj zwykły, odpoczynek, bez zadań z bossem): zadanie główne płaci na poziomach od swojego do poziomu przed następnym zadaniem głównym (proporcjonalnie do `Exp.expToNext`), poboczne × `SIDE_SHARE` w swoim paśmie, nadmiar EXP przechodzi dalej. Wiersze 20 i 21 zależą od zadań Boru (S92), poza fixture."
	)
	for L = 1, 21 do
		local w = B.paceWindowAt("Warrior", L)
		local m = B.paceWindowMean("Warrior", L)
		local prev = if L > 1 then B.paceWindowMean("Warrior", L - 1) else 0
		local ratio = if prev > 1e-6 then m / prev else 0 / 0 -- no ratio after levels paid in full by the tutorial
		local prevH = if L > 1 then B.paceWindowAt("Warrior", L - 1).hours else 0
		local raw = if prevH > 1e-6 then w.hours / prevH else 0 / 0
		-- S91: h(20), m(20) i krok 19 -> 20 zależą od `toDuskwood` (S92), asertowane w balance.spec
		row(
			tostring(L),
			{ { w.hours, "2" }, { m, "2" }, { ratio, "2" }, { w.questExp, "i" }, { w.carryIn, "i" }, { raw, "2" } },
			if L >= 20 then false else nil
		)
	end
	do
		local sum, sumBoss, sumKind = 0, 0, 0
		for L = 1, 19 do
			sum += B.paceWindowAt("Warrior", L).hours
			sumBoss += B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours
			sumKind += B.paceWindowAt("Warrior", L, { kind = "kindAt" }).hours
		end
		row("suma 1–19", { { sum, "2" }, { 0 / 0, "2" }, { 0 / 0, "2" }, { 0 / 0, "i" }, { 0 / 0, "i" } })
		row("suma 1–19 z zadaniem Grimroka", { { sumBoss, "2" }, { 0 / 0, "2" } })
		row("suma 1–19 z rodzajami Łąk (`kindAt`)", { { sumKind, "2" }, { 0 / 0, "2" } })
	end

	section(
		"Warstwa umiejętności na 5 / 10 / 15 / 20 (S91)",
		{ "klasa · build · poziom", "R1", "T-SK2", "T-SK3", "DPS 1 cel 60 s", "grupa 3 × 8 s", "maks. HP", "EHP" },
		"`tests/SkillModel.luau`: podstawa klasy na rangach z poziomu, buildy wzorcowe przycięte do poziomu (10 punktów na 20.), ekwipunek konwencji. Kotwica L20 w tabeli niżej."
	)
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			local levels = if build.base then { 5, 10, 15 } else { 10, 15 }
			for _, L in levels do
				local m = SkillModel.metrics(build, L)
				row(`{c} {build.key} {L}`, {
					{ m.r1, "2" },
					{ m.tsk2, "2" },
					{ m.tsk3, "2" },
					{ m.single60, "i" },
					{ m.aoe3burst, "i" },
					{ m.maxHp, "i" },
					{ m.ehp, "1" },
				})
			end
		end
	end

	section(
		"Kotwica L20 (S91)",
		{
			"klasa · build",
			"R1",
			"T-SK2",
			"T-SK3",
			"DPS 1 cel 60 s",
			"grupa 3 × 8 s",
			"maks. HP",
			"EHP",
			"T-SK4 / T-SK5",
		},
		"Stan po przestrojeniu 1–20 (S91): podstawa klasy bez ścieżki głównej i każdy build wzorcowy przycięty do L20 (ścieżka główna świeżo wybrana, 10 punktów). T-SK4 dla Maga, T-SK5 (Leczenie na Obrońcy) dla Kapłana. Od S91 każda zmiana tej tabeli to wpis w `ALLOWED_1_20_DIFFS`; S92–S94 asertują strażniki T-SK względem tych liczb (`SkillModel.guards`)."
	)
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			local m = SkillModel.metrics(build, 20)
			local extra = if c == "Mage"
				then m.tsk4
				elseif c == "Cleric" then SkillModel.oneHeal(build, 20, SkillModel.defenderTank(20))
				else 0 / 0
			row(`{c} {build.key}`, {
				{ m.r1, "2" },
				{ m.tsk2, "2" },
				{ m.tsk3, "2" },
				{ m.single60, "i" },
				{ m.aoe3burst, "i" },
				{ m.maxHp, "i" },
				{ m.ehp, "1" },
				{ extra, "2" },
			})
		end
	end
	do
		local healer = SkillModel.build("healer.dungeon", "Cleric")
		local r = SkillModel.healerVsBoss(healer, "grimrok", { team = "s92" })
		row("T-SK6 Grimrok (Uzdrowiciel lochowy na Obrońcy)", { { r.tsk6, "2" } })
		for _, c in B.CLASSES do
			local p = B.player(c, 20)
			local f = B.duel(p, B.monster(B.GENERIC, 20))
			local g = B.expectedGroup(p, B.GENERIC, 20)
			row(`konwencja {c} 20: 1 na 1 s / HP, grupa`, { { f.seconds, "s" }, { f.hpLost, "%" }, { g.hpLost, "%" } })
		end
	end

	section(
		"Elity z prawdziwych spawnerów Łąk (S91)",
		{
			"jaskinia · rodzaj · poziom · klasa · wariant",
			"pojedyncza s",
			"pojedyncza HP",
			"para HP",
			"spotkanie HP",
		},
		'`Balance.caveElites("meadows")` (q par z prawdziwych spawnerów po `elitePairChance.meadows`), gracz bez węzłów i z węzłami (`buildsAt`). Wiersze z Elitą powyżej 20. poziomu (spawner 19–20) poza fixture.'
	)
	for _, withNodes in { false, true } do
		for _, cave in B.caveElites("meadows", withNodes) do
			for _, kind in cave.kinds do
				for _, f in kind.fights do
					local label =
						`{cave.id} {kind.kind} {f.level} {f.classId}{if f.variant then " " .. f.variant else ""}`
					-- S91: Elita spawnera 19-20 ma poziom 21-22 (krzywe S87 / S92), asertowane w balance.spec
					row(label, {
						{ f.single.seconds, "s" },
						{ f.single.hpLost, "%" },
						{ f.pair.hpLost, "%" },
						{ f.encounter, "%" },
					}, if f.level + 2 > 20 then false else nil)
				end
			end
		end
	end
	section(
		"Elita II jaskiń Łąk (S91)",
		{ "jaskinia · rodzaj · spawner · wariant", "solo HP", "2 graczy HP", "3 graczy HP", "4 graczy HP" },
		'`Balance.caveElites("meadows")`: drużyna `Balance.team` (W, M, Ł, K) na poziomie spawnera + 2, Elita II na spawnerze + 4. Cel `REGION_TARGETS.elite2`. Spawner 17–20 poza fixture.'
	)
	for _, withNodes in { false, true } do
		for _, cave in B.caveElites("meadows", withNodes) do
			for _, e in cave.elite2 do
				local label = `{cave.id} {e.kind} {e.spawner}{if withNodes then " z węzłami" else ""}`
				-- S91: Elita II spawnera 17-20 ma poziom 21-24 (krzywe S87 / S92), asertowane w balance.spec
				row(label, {
					{ e.byTeam[1].hpLost, "%" },
					{ e.byTeam[2].hpLost, "%" },
					{ e.byTeam[3].hpLost, "%" },
					{ e.byTeam[4].hpLost, "%" },
				}, if e.spawner + 4 > 20 then false else nil)
			end
		end
	end

	section(
		"Grimrok w modelu S83 / S87 (S91)",
		{ "drużyna", "walka min", "tank obrażenia/s", "największy cios Mag", "fazy tarczy s" },
		"`Balance.bossFight` z harmonogramem `Logic/BossSchedule` (S87), drużyna L19 (W, M, Ł, K, W), bez i z węzłami (`Balance.COMBAT_BUILD`). Bez wsparcia: buildy bojowe przycięte do 19 (Furia, Królobójca, Arkanista boss, Inkwizytor solo, Niszczyciel boss), obrażenia graczy z `tests/SkillModel.luau`."
	)
	for _, withNodes in { false, true } do
		for n = 1, 5 do
			local f = B.bossFight("grimrok", B.team(n, 19, withNodes))
			row(`{n}{if withNodes then " z węzłami" else ""}`, {
				{ f.seconds / 60, "2" },
				{ f.tankDps, "1" },
				{ f.biggestHit.Mage or 0 / 0, "%" },
				{ f.shieldSeconds, "s" },
			})
		end
	end
	section(
		"S91: tylko raport (tempo, mikstury, rangi)",
		{ "pozycja", "wartość" },
		"Pozycje „tylko raport” z S91 (bez fixture): EXP na godzinę z miksturami łańcuchowymi wobec odpoczynku i udział mikstur w złocie z walki (Wojownik, rodzaj zwykły), tempo 1 → 20 innych klas (model okna), suma rang podstawy klasy na 10 / 15 / 20 (rangi z poziomu, ROZWOJ 2.5). Wartości cech na 20 (lista S88) i Kusza na 20 (S90): tabele przedmiotów i S88.",
		false
	)
	for _, L in { 5, 10, 15, 19 } do
		local rest = B.paceAt("Warrior", L, { kind = B.GENERIC })
		local chain = B.paceAt("Warrior", L, { kind = B.GENERIC, potions = "chain" })
		row(`EXP/h łańcuch / odpoczynek L{L}`, { { chain.expPerHour / math.max(1e-9, rest.expPerHour), "2" } }, false)
		local income = chain.goldPerKill + chain.dropPerKill
		row(`mikstury / złoto z walki L{L}`, { { chain.potionGoldPerKill / math.max(1e-9, income), "%" } }, false)
	end
	for _, c in B.CLASSES do
		local sum = 0
		for L = 1, 19 do
			sum += B.paceWindowAt(c, L).hours
		end
		row(`tempo 1 → 20 {c} (h)`, { { sum, "2" } }, false)
		for _, L in { 10, 15, 20 } do
			local ranks = 0
			for _, def in SkillData.byClass[c] do
				ranks += Skills.rankFor(c, L, def)
			end
			row(`rangi podstawy {c} L{L}`, { { ranks, "i" } }, false)
		end
	end

	section(
		"Grimrok bez wsparcia (S91)",
		{
			"drużyna",
			"walka s",
			"limit s",
			"przyjmowane / podtrzymanie (najgorszy)",
			"największy cios / HP",
			"mikstury (najwięcej)",
		},
		"Odpowiedź 26, ROZWOJ 7.5: bez przechwytu, leczenia innych i prowokacji; mikstury co `Potions.interval(19)`, regeneracja w walce i kradzież życia. Cel: walka ≤ 80% `enrageAfter`, stosunek ≤ 1,0, żaden cios ≥ 100% HP."
	)
	for n = 3, 5 do
		local r = B.bossNoSupport("grimrok", n)
		local worst, hit, potions = 0, 0, 0
		for _, mem in r.members do
			worst = math.max(worst, mem.ratio)
			hit = math.max(hit, mem.biggest)
			potions = math.max(potions, mem.potions)
		end
		row(tostring(n), {
			{ r.seconds, "s" },
			{ r.limit, "s" },
			{ worst, "2" },
			{ hit, "%" },
			{ potions, "1" },
		})
	end
	return tb.tables
end

-- Bands 20-100 (S83 world model) --------------------------------------------------------------------------------

local CLASS_PL = { Warrior = "Wojownik", Hunter = "Łowca", Mage = "Mag", Cleric = "Kapłan" }
BalanceTables.CLASS_PL = CLASS_PL

local function bandName(lo: number, hi: number): string
	return `{lo}-{hi}`
end

local function stepLevels(lo: number, hi: number): { number }
	local out = {}
	for L = lo, hi, 5 do
		table.insert(out, L)
	end
	return out
end

-- Tables of the regions' kinds, caves and boss (also for the Meadows in band 1-20; never in the fixture).
function BalanceTables.regionTables(mapId: string, band: string): { Table }
	local tb = BalanceTables.builder(band)
	local section, row = tb.section, tb.row
	local suffix = ` ({band}, {mapId})`

	section(
		`Rodzaje regionu{suffix}`,
		{
			"rodzaj",
			"poziom",
			"EXP/s ÷ zwykły",
			"HP/EXP ÷ średnia regionu",
			"rzucający",
		},
		"Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25."
	)
	for _, k in B.kindRates(mapId, mapId == "meadows") do
		row(k.kind, {
			{ k.level, "i" },
			{ k.expPerSecond, "2" },
			{ k.hpPerExp, "2" },
			{ if k.caster then 1 else 0, "i" },
		})
	end

	local caves = B.caveElites(mapId)
	section(
		`Jaskinie: Elity solo i w parze{suffix}`,
		{
			"jaskinia · rodzaj · poziom",
			"q par",
			"Wojownik s",
			"Wojownik HP",
			"Łowca s",
			"Łowca HP",
			"Mag s",
			"Mag HP",
			"Kapłan s",
			"Kapłan HP",
			"Wojownik para HP",
			"Mag para HP",
			"Wojownik spotkanie",
			"Mag spotkanie",
		},
		'Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.'
	)
	for _, cave in caves do
		for _, kind in cave.kinds do
			local byLevel: { [number]: { [string]: any } } = {}
			local order: { number } = {}
			for _, f in kind.fights do
				if not byLevel[f.level] then
					byLevel[f.level] = {}
					table.insert(order, f.level)
				end
				byLevel[f.level][f.classId] = f
			end
			for _, L in order do
				local f = byLevel[L]
				local cells: { { any } } = { { cave.pairShare, "%" } }
				for _, c in B.CLASSES do
					table.insert(cells, { f[c].single.seconds, "s" })
					table.insert(cells, { f[c].single.hpLost, "%" })
				end
				table.insert(cells, { f.Warrior.pair.hpLost, "%" })
				table.insert(cells, { f.Mage.pair.hpLost, "%" })
				table.insert(cells, { f.Warrior.encounter, "%" })
				table.insert(cells, { f.Mage.encounter, "%" })
				row(`{cave.id} · {kind.kind} · {L}`, cells)
			end
		end
	end

	section(
		`Jaskinie: Elita II{suffix}`,
		{
			"jaskinia · rodzaj · poziom spawnera",
			"poziom graczy",
			"solo HP",
			"2 graczy HP",
			"3 graczy HP",
			"4 graczy HP",
			"3 graczy s",
		},
		"Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%."
	)
	for _, cave in caves do
		for _, e in cave.elite2 do
			row(`{cave.id} · {e.kind} · {e.spawner}`, {
				{ e.playerLevel, "i" },
				{ e.byTeam[1].hpLost, "%" },
				{ e.byTeam[2].hpLost, "%" },
				{ e.byTeam[3].hpLost, "%" },
				{ e.byTeam[4].hpLost, "%" },
				{ e.byTeam[3].seconds, "s" },
			})
		end
	end

	local def = Bosses.forRegion(mapId) :: any
	if def then
		local phaseCount = #def.phases + 1
		local columns = { "atak" }
		for phase = 1, phaseCount do
			table.insert(columns, `faza {phase} /min`)
			table.insert(columns, `faza {phase} tempo`)
		end
		section(
			`Boss {def.id}: harmonogram ataków{suffix}`,
			columns,
			"`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%."
		)
		local cads = {}
		for phase = 1, phaseCount do
			cads[phase] = B.bossCadence(def, phase)
		end
		for _, attack in def.attacks do
			local cells: { { any } } = {}
			for phase = 1, phaseCount do
				table.insert(cells, { cads[phase].perMinute[attack.id] or 0 / 0, "1" })
				table.insert(cells, { cads[phase].rateShare[attack.id] or 0 / 0, "%" })
			end
			row(attack.id, cells)
		end
		local casting: { { any } } = {}
		for phase = 1, phaseCount do
			table.insert(casting, { cads[phase].casting, "%" })
			table.insert(casting, { 0 / 0, "%" })
		end
		row("udział rzucania", casting)

		section(
			`Boss {def.id}: walka{suffix}`,
			{
				"drużyna · wariant",
				"walka min",
				"tarcze s",
				"pomocnicy na tanku HP",
				"wściekłość",
				"tank HP/s",
				"tank HP/s ÷ HP",
				"mikstura HP/s",
				"max cios Wojownik",
				"max cios Łowca",
				"max cios Mag",
				"max cios Kapłan",
			},
			"Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%)."
		)
		local L = math.min(100, def.level)
		for _, n in { 3, 5 } do
			for _, variant in { "połowa", "wszystkie" } do
				local opts = if variant == "wszystkie" then { specialHit = 1, hazardShare = 1 } else nil
				local team = {}
				for i = 1, n do
					table.insert(team, B.cachedPlayer(B.ORDER[i], L))
				end
				local f = B.bossFight(def.id, team, opts)
				local shield = 0
				for _, p in f.phases do
					shield += p.shieldSeconds
				end
				local single: { [string]: number } = {}
				for _, c in B.CLASSES do
					single[c] = f.biggestHit[c] or 0 / 0
				end
				row(`{n} · {variant}`, {
					{ f.seconds / 60, "1" },
					{ shield, "s" },
					{ f.shieldTankHp, "%" },
					{ if f.enraged then 1 else 0, "i" },
					{ f.tankDps, "i" },
					{ f.tankDps / team[1].values.maxHp, "%" },
					{ f.potionHps, "i" },
					{ single.Warrior, "%" },
					{ single.Hunter, "%" },
					{ single.Mage, "%" },
					{ single.Cleric, "%" },
				})
			end
		end

		local hazard = B.HAZARDS[def.id]
		if hazard then
			section(
				`Boss {def.id}: zagrożenie skryptu{suffix}`,
				{ "klasa", "jedno trafienie HP", "HP/s", "HP/s ÷ mikstura HP/s" },
				`Faza {hazard.phase}: ×{hazard.damage} ataku bossa ({hazard.damageKind}) co {hazard.every} s na każdego poza bezpiecznym miejscem.`
					.. (
						if def.id == "azgor"
							then " Lawa: bezpieczny krąg kurczy się z 50 do 20 st. w 120 s; dane nie mają promienia walki wręcz, więc walczący wręcz przy bossie w środku areny mieszczą się w kręgu przez całą fazę (sprawdzić w S87, gdy boss nie stoi w środku)."
							else ""
					)
			)
			local team = {}
			for i = 1, 4 do
				table.insert(team, B.cachedPlayer(B.ORDER[i], L))
			end
			local f = B.bossFight(def.id, team)
			for _, c in B.CLASSES do
				local hz = f.hazards :: any
				row(CLASS_PL[c], {
					{ hz.perTick[c], "%" },
					{ hz.hps[c], "i" },
					{ hz.hps[c] / math.max(1e-9, f.potionHps), "2" },
				})
			end
		end
	end
	return tb.tables
end

-- Tables of a band 20-45 / 45-70 / 70-100 at L = lo, lo + 5, ..., hi, plus its region (regionTables).
function BalanceTables.tablesBand(lo: number, hi: number): { Table }
	local band = bandName(lo, hi)
	local tb = BalanceTables.builder(band)
	local section, row = tb.section, tb.row
	local suffix = ` ({band})`
	local levels = stepLevels(lo, hi)
	local mapId = B.REGION_IDS[B.regionAt(lo)]

	section(
		`Gracz z ekwipunkiem na poziomie{suffix}`,
		{
			"poziom",
			"Wojownik HP",
			"Wojownik DPS",
			"Łowca HP",
			"Łowca DPS",
			"Mag HP",
			"Mag DPS",
			"Kapłan HP",
			"Kapłan DPS",
		},
		"Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; DPS z 1–2 umiejętnościami (×1,2) przeciw zwykłemu potworowi poziomu."
	)
	for _, L in levels do
		local cells = {}
		for _, c in B.CLASSES do
			local p = B.cachedPlayer(c, L)
			table.insert(cells, { p.values.maxHp, "i" })
			table.insert(cells, { B.dps(p, B.monster(B.GENERIC, L)), "i" })
		end
		row(tostring(L), cells)
	end

	section(`Zwykły potwór{suffix}`, { "poziom", "HP", "atak", "pancerz", "EXP", "złoto", "EXP do poziomu" })
	for _, L in levels do
		local m = B.monster(B.GENERIC, L)
		row(tostring(L), {
			{ m.maxHp, "i" },
			{ m.attack, "1" },
			{ m.armor, "i" },
			{ B.killExp(L, B.GENERIC, L), "i" },
			{ B.killGold(L, B.GENERIC, L), "1" },
			{ Exp.expToNext(L), "i" },
		})
	end

	section(`1 na 1 z potworem poziomu (G1){suffix}`, {
		"poziom",
		"Wojownik s",
		"Wojownik HP",
		"Łowca s",
		"Łowca HP",
		"Mag s",
		"Mag HP",
		"Kapłan s",
		"Kapłan HP",
	}, "Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.")
	for _, L in levels do
		local cells = {}
		for _, c in B.CLASSES do
			local f = B.duel(B.cachedPlayer(c, L), B.monster(B.GENERIC, L))
			table.insert(cells, { f.seconds, "s" })
			table.insert(cells, { f.hpLost, "%" })
		end
		row(tostring(L), cells)
	end

	section(`Grupy (G2) i trzy potwory bez umiejętności (G3){suffix}`, {
		"klasa · poziom",
		"grupa średnio HP",
		"grupa 4 HP",
		"czas średnio s",
		"trzy bez umiejętności HP",
	}, "Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.")
	for _, c in B.CLASSES do
		for _, L in levels do
			local p = B.cachedPlayer(c, L)
			local g = B.expectedGroup(p, B.GENERIC, L)
			local skill = B.SKILL_DPS
			B.SKILL_DPS = 1
			local three = B.groupFight(p, B.group(B.GENERIC, L, 3))
			B.SKILL_DPS = skill
			row(`{c} {L}`, {
				{ g.hpLost, "%" },
				{ g.bySize[4].hpLost, "%" },
				{ g.seconds, "s" },
				{ three.hpLost, "%" },
			})
		end
	end

	section(
		`Sprzęt ze sklepu (G4) i klasy (G5, G6){suffix}`,
		{
			"poziom",
			"Wojownik sklep s",
			"Wojownik sklep HP",
			"Kapłan sklep s",
			"Kapłan sklep HP",
			"DPS Łowca / Wojownik",
			"moc Łowca / Wojownik",
			"rozrzut 1 na 1",
		},
		"Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2."
	)
	for _, L in levels do
		local m = B.monster(B.GENERIC, L)
		local cells: { { any } } = {}
		for _, c in { "Warrior", "Cleric" } do
			local p = B.player(c, L, { ilvl = Items.generate.tierFor(L), weaponIlvl = B.shopTier(L) })
			local f = B.duel(p, m)
			table.insert(cells, { f.seconds, "s" })
			table.insert(cells, { f.hpLost, "%" })
		end
		local w, h = B.cachedPlayer("Warrior", L), B.cachedPlayer("Hunter", L)
		local lo2, hi2 = math.huge, 0
		for _, c in B.CLASSES do
			local s = B.duel(B.cachedPlayer(c, L), m).seconds
			lo2, hi2 = math.min(lo2, s), math.max(hi2, s)
		end
		table.insert(cells, { B.dps(h, m) / B.dps(w, m), "2" })
		table.insert(cells, { B.power(h) / B.power(w), "2" })
		table.insert(cells, { hi2 / lo2, "2" })
		row(tostring(L), cells)
	end

	-- Pace: the whole band level by level with carried quest EXP; rows every 5 levels
	local plain = B.paceBand("Warrior", lo, hi)
	local best = B.paceBand("Warrior", lo, hi, { area = "best" })
	local chain = B.paceBand("Warrior", lo, hi, { potions = "chain" })
	local bosses = B.paceBand("Warrior", lo, hi, { bosses = true })
	local generic = B.paceBand("Warrior", lo, hi, { kind = B.GENERIC })
	section(
		`Tempo (Wojownik){suffix}`,
		{
			"poziom · rodzaj",
			"EXP/zabicie",
			"s/zabicie",
			"h/poziom",
			"udział zadań",
			"odpoczynek",
			"h najlepsze łowisko",
			"h mikstury",
			"h rodzaj ogólny",
		},
		"Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`."
	)
	for _, L in levels do
		local i = L - lo + 1
		local pace = plain.levels[i]
		if pace then
			row(`{L} {pace.kind}`, {
				{ pace.expPerKill, "i" },
				{ pace.secondsPerKill, "s" },
				{ pace.hours, "2" },
				{ math.min(1, pace.questExp / math.max(1, Exp.expToNext(L))), "%" },
				{ pace.restShare, "%" },
				{ best.levels[i].hours, "2" },
				{ chain.levels[i].hours, "2" },
				{ generic.levels[i].hours, "2" },
			})
		end
	end
	local target = 0 / 0
	for _, b in B.BAND_HOURS do
		if b[1] == lo then
			target = b[3]
		end
	end
	row("suma pasma", {
		{ 0 / 0, "i" },
		{ 0 / 0, "s" },
		{ plain.hours, "1" },
		{ 0 / 0, "%" },
		{ 0 / 0, "%" },
		{ best.hours, "1" },
		{ chain.hours, "1" },
		{ generic.hours, "1" },
	})
	row("suma z bossami w zadaniach", {
		{ 0 / 0, "i" },
		{ 0 / 0, "s" },
		{ bosses.hours, "1" },
		{ 0 / 0, "%" },
		{ 0 / 0, "%" },
		{ 0 / 0, "1" },
		{ 0 / 0, "1" },
		{ 0 / 0, "1" },
	})
	row("cel D4 (wstępny)", {
		{ 0 / 0, "i" },
		{ 0 / 0, "s" },
		{ target, "1" },
		{ 0 / 0, "%" },
		{ 0 / 0, "%" },
		{ 0 / 0, "1" },
		{ 0 / 0, "1" },
		{ 0 / 0, "1" },
	})

	section(
		`Zadania na swoim poziomie{suffix}`,
		{
			"poziom",
			"główne EXP",
			"poboczne EXP (×0,5)",
			"boss EXP",
			"dzienne EXP/dzień",
			"dzienne ÷ poziom",
			"główne złoto",
		},
		"Zadania liczą się na poziomie zadania (bez rozkładania); boss tylko z opcją `bosses`. Dzienne: 3 kontrakty × `Daily.reward` (15% poziomu), tylko raport."
	)
	for L = lo, hi - 1 do
		local q = B.questsAt(L, { bosses = true })
		if q.main + q.side + q.boss > 0 or L % 5 == 0 then
			row(tostring(L), {
				{ q.main, "i" },
				{ q.side, "i" },
				{ q.boss, "i" },
				{ q.daily, "i" },
				{ q.daily / math.max(1, Exp.expToNext(L)), "%" },
				{ q.gold, "i" },
			})
		end
	end

	local mid = levels[math.ceil(#levels / 2)]
	section(
		`Premia za różne klasy (poziom {mid}){suffix}`,
		{
			"drużyna",
			"mnożnik EXP",
			"EXP/h członka",
			"h pasma",
		},
		"Założenie modelu: drużyna bije na tym samym łowisku osobno i dzieli zaliczenie, bez synergii (S85–S86), więc EXP/h członka = średnia solowych EXP/h × `PartyBonus.expMul`; `floor` z `PartyLoot.splitExp` pominięty."
	)
	for _, spec in
		{
			{ "solo (Wojownik)", nil },
			{ "3 × Wojownik", { "Warrior", "Warrior", "Warrior" } },
			{ "Wojownik + Łowca + Mag", { "Warrior", "Hunter", "Mage" } },
			{ "cztery klasy", { "Warrior", "Hunter", "Mage", "Cleric" } },
		}
	do
		local party = spec[2] :: { string }?
		local pace = B.paceAt("Warrior", mid, { party = party })
		local hours = B.paceBand("Warrior", lo, hi, { party = party }).hours
		row(spec[1] :: string, { { pace.expMul, "2" }, { pace.expPerHour, "i" }, { hours, "1" } })
	end

	section(
		`Ekonomia (Wojownik){suffix}`,
		{
			"poziom",
			"złoto z zabić/h",
			"sprzedaż dropu/h",
			"mikstury/h",
			"mikstury ÷ dochód",
			"drop ÷ zabicia",
			"złoto zadań poziomu",
			"łańcuch: mikstury ÷ dochód",
		},
		"Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku."
	)
	for _, L in levels do
		local e = B.economyAt("Warrior", L)
		local c = B.economyAt("Warrior", L, { potions = "chain" })
		row(tostring(L), {
			{ e.killGold, "i" },
			{ e.dropGold, "i" },
			{ e.potionGold, "i" },
			{ e.potionShare, "%" },
			{ e.dropToKill, "2" },
			{ e.questGold, "i" },
			{ c.potionShare, "%" },
		})
	end

	section(
		`Mikstury (Wojownik, łańcuch zamiast odpoczynku){suffix}`,
		{
			"poziom",
			"odstęp s",
			"jakość",
			"łyki na walkę",
			"czekanie s",
			"złoto na walkę",
			"mikstura HP/s",
		},
		"Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem."
	)
	for _, L in levels do
		local pace = B.paceAt("Warrior", L, { potions = "chain" })
		local use = pace.potions :: any
		row(tostring(L), {
			{ Potions.interval(L), "1" },
			{ use.quality, "i" },
			{ use.drinks, "2" },
			{ use.wait, "s" },
			{ use.gold, "i" },
			{ B.potionHps(L), "i" },
		})
	end

	for _, t in BalanceTables.regionTables(mapId, band) do
		table.insert(tb.tables, t)
	end
	return tb.tables
end

-- Every table of the report 1-100 (1-20, the Meadows' region tables, the three bands, the S84 item tables, the S85
-- skill tables).
function BalanceTables.tablesAll(): { Table }
	local out = BalanceTables.tables1_20()
	for _, t in BalanceTables.regionTables("meadows", "1-20") do
		table.insert(out, t)
	end
	for _, band in B.BANDS do
		if band[1] >= 20 then
			for _, t in BalanceTables.tablesBand(band[1], band[2]) do
				table.insert(out, t)
			end
		end
	end
	for _, t in BalanceTables.tablesItems() do
		table.insert(out, t)
	end
	for _, t in BalanceTables.tablesSkills() do
		table.insert(out, t)
	end
	for _, t in BalanceTables.tablesPaths() do
		table.insert(out, t)
	end
	return out
end

-- Skills on the reference builds (S85) ----------------------------------------------------------------------------

local SkillModel = require("./SkillModel")

-- S85 (H2, H3): reference numbers the model is compared with (diagnosis 3f935c1 = balance plan D1, ROZWOJ 2.5 / 9.6 /
-- 11.6 / 12.7) and the cause of a difference above 10 % in one word (docs/SESJE.md S85 explains each).
BalanceTables.SKILL_REFERENCES = {
	d1 = {
		tsk1 = { Warrior = 1.90, Hunter = 2.12, Mage = 2.37, Cleric = 1.83 },
		tsk2 = { Warrior = 2.31, Hunter = 2.58, Mage = 2.62, Cleric = 1.96 },
		tsk3 = { Warrior = 1.54, Hunter = 1.29, Mage = 1.21, Cleric = 1.48 },
		tsk4 = 2.8,
		tsk5 = 0.28,
		tsk6 = 1.11,
	},
	rozwoj25 = { Warrior = 1.84, Hunter = 1.97, Mage = 2.22, Cleric = 1.74 },
	healer96 = { [20] = 0.21, [45] = 0.30, [70] = 0.33, [100] = 0.38 },
	fortune96 = { [20] = 0.20, [45] = 0.26, [70] = 0.28, [100] = 0.30 },
	hunter116 = { [20] = 1.52, [45] = 1.40, [70] = 1.40, [100] = 1.30 },
	mageExp127 = { [45] = 1.28, [70] = 1.13, [100] = 1.05 },
	mageBoss127 = { [45] = 1.38, [70] = 1.27, [100] = 1.18 },
} :: any
BalanceTables.SKILL_CAUSES = {
	["d1.tsk1.Warrior"] = "węzły",
	["d1.tsk2.Warrior"] = "węzły",
	["d1.tsk2.Hunter"] = "węzły",
	["d1.tsk3.Hunter"] = "węzły",
	["d1.tsk1.Mage"] = "rangi",
	["d1.tsk2.Mage"] = "rangi",
	["d1.tsk3.Mage"] = "rangi",
	["d1.tsk1.Cleric"] = "normalizacja",
	["d1.tsk2.Cleric"] = "normalizacja",
	["d1.tsk3.Cleric"] = "rotacja",
	["d1.tsk4"] = "rotacja",
	["d1.tsk5"] = "wzór",
	["d1.tsk6"] = "rotacja",
	["rozwoj25.Warrior"] = "węzły",
	["rozwoj25.Hunter"] = "węzły",
	["rozwoj25.Mage"] = "rangi",
	["rozwoj25.Cleric"] = "normalizacja",
	["healer96"] = "węzły",
	["fortune96"] = "węzły",
	["hunter116"] = "węzły",
	["mageExp127"] = "żywioły",
	["mageBoss127"] = "żywioły",
} :: { [string]: string }

local SKILL_NOTE =
	"S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami."

local function weaponLabel(build: SkillModel.Build): string
	return if build.weapon.offhand then `{build.weapon.main} + {build.weapon.offhand}` else build.weapon.main
end

-- The S85 tables (band "S85-skills"): T-SK1..3, resources and T-SK4, unmodelled counts, damage shares, T-SK5 / T-SK6
-- and the comparisons, in report order. Every number comes from tests/SkillModel.luau.
function BalanceTables.tablesSkills(): { Table }
	local started = os.clock()
	local tb = BalanceTables.builder("S85-skills")
	local section, row = tb.section, tb.row
	local LEVELS = SkillModel.LEVELS
	for _, c in B.CLASSES do
		section(
			`T-SK1–3: {CLASS_PL[c]}`,
			{
				"build · broń · poziom",
				"atak podst.",
				"na odnowieniu",
				"wybuch 8 s",
				"60 s",
				"obszar 3 · 8 s",
				"obszar 3 · 60 s",
				"T-SK1",
				"T-SK1 / L20",
				"T-SK2",
				"T-SK2 / L20",
				"T-SK3",
				"areaCap",
			},
			"DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. "
				.. SKILL_NOTE
		)
		for _, build in SkillModel.builds(c) do
			for _, L in LEVELS do
				local m = SkillModel.metrics(build, L)
				row(`{build.key} · {weaponLabel(build)} · {L}`, {
					{ m.basic },
					{ m.onCooldown },
					{ m.burst8 },
					{ m.sustained60 },
					{ m.aoe3burst },
					{ m.aoe3sus },
					{ m.tsk1, "2" },
					{ m.tsk1rel, "2", nil, 1.15 },
					{ m.tsk2, "2" },
					{ m.tsk2rel, "2", nil, 1.25 },
					{ m.tsk3, "2", nil, build.areaCap },
					{ build.areaCap, "1" },
				})
			end
		end
	end
	section(
		"Mag: żywioły broni",
		{ "build · poziom · żywioł", "60 s", "wybuch 8 s", "obszar 3 · 8 s", "T-SK1", "T-SK2", "T-SK3", "T-SK4" },
		"Rozbicie średniej Maga na żywioł broni (`GearOpts.element`, `Skills.elementAllowed`, efekt adaptacyjny); raport. "
			.. SKILL_NOTE
	)
	for _, build in SkillModel.builds("Mage") do
		for _, L in LEVELS do
			local byElement: any = SkillModel.metrics(build, L).byElement or {}
			for _, element in SkillModel.ASSUMPTIONS.elements do
				local m = byElement[element]
				if m then
					row(`{build.key} · {L} · {element}`, {
						{ m.sustained60 },
						{ m.burst8 },
						{ m.aoe3burst },
						{ m.tsk1, "2" },
						{ m.tsk2, "2" },
						{ m.tsk3, "2" },
						{ m.tsk4, "2" },
					})
				end
			end
		end
	end
	for _, c in B.CLASSES do
		section(
			`Zasoby: {CLASS_PL[c]}`,
			{
				"build · poziom",
				"pula",
				"regeneracja / s",
				"na odnowieniu / s",
				if c == "Mage" then "T-SK4" else "zapotrzebowanie / regeneracja",
				"60 s",
				"60 s z miksturami",
				"mikstury / min",
				"punkty wydane",
				"punkty wolne",
			},
			"Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. "
				.. SKILL_NOTE
		)
		for _, build in SkillModel.builds(c) do
			for _, L in LEVELS do
				local m = SkillModel.metrics(build, L)
				local band = if c == "Mage" and L >= 45 then SkillModel.TSK4_BANDS[build.key] or { 2.0, 3.0 } else nil
				row(`{build.key} · {L}`, {
					{ m.pool },
					{ m.regen, "1" },
					{ m.demand, "1" },
					{ m.tsk4, "2", if band then band[1] else nil, if band then band[2] else nil },
					{ m.sustained60 },
					{ m.sustained60p },
					{ m.potionsPerMinute, "1" },
					{ m.spent },
					{ m.free },
				})
			end
		end
	end
	section(
		"Brak do S86 (liczby)",
		{ "klasa · build · poziom", "pozycje unmodelled", "pominięte rzuty (60 s)", "aktywne poza rotacją" },
		"Ile mechanik model jeszcze nie liczy (lista w sekcji „Brak do S86”); pominięte rzuty: wpisy rotacji z typem, warunkiem lub mechaniką S86, liczone raz na odnowienie. "
			.. SKILL_NOTE
	)
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			for _, L in { 45, 100 } do
				local m = SkillModel.metrics(build, L)
				local skipped = 0
				for _, s in m.skipped do
					skipped += s.count
				end
				row(`{c} · {build.key} · {L}`, { { #m.unmodelled }, { skipped }, { #m.offRotation } })
			end
		end
	end
	section(
		"Udziały w obrażeniach 60 s",
		{ "build · poziom · umiejętność", "udział" },
		"Pięć największych udziałów umiejętności (i ataku podstawowego, `basic`) w obrażeniach ciągłej walki 60 s na 1 manekinie, wiersz na umiejętność; raport dla S89–S90. "
			.. SKILL_NOTE
	)
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			for _, L in { 45, 70, 100 } do
				local list: { { any } } = {}
				for id, v in SkillModel.metrics(build, L).shares do
					table.insert(list, { id, v })
				end
				table.sort(list, function(a: { any }, b: { any }): boolean
					if a[2] ~= b[2] then
						return a[2] > b[2]
					end
					return a[1] < b[1]
				end)
				-- one row per skill: the snapshot key follows the skill, not its rank
				for i = 1, math.min(5, #list) do
					row(`{c} {build.key} · {L} · {list[i][1]}`, { { list[i][2], "%" } })
				end
			end
		end
	end
	local band5 = SkillModel.TSK5_BAND
	section(
		"T-SK5: jedno Leczenie / maks. HP tanka",
		{ "build · poziom", "tank Wojownik (konwencja)", "tank Strażnik „Obrońca”" },
		"`Skills.healAmount` (część od maks. HP tanka i od ataku magicznego na krzywej `heal`) × `healPower`, premie leczenia innego gracza i oczekiwany krytyk leczenia; cel 25–35% asertują S87 (G10) i S89. "
			.. SKILL_NOTE
	)
	for _, build in SkillModel.builds("Cleric") do
		for _, L in LEVELS do
			row(`{build.key} · {L}`, {
				{ SkillModel.oneHeal(build, L), "%", band5[1], band5[2] },
				{ SkillModel.oneHeal(build, L, SkillModel.defenderTank(L)), "%", band5[1], band5[2] },
			})
		end
	end
	section(
		"T-SK6: leczenie na tanku / obrażenia tanka na bossie",
		{
			"build · boss (poziom drużyny)",
			"drużyna domyślna",
			"drużyna S92",
			"leczenie / s (domyślna)",
			"obrażenia tanka / s",
			"czas walki s",
			"mana: zapotrzebowanie / regeneracja",
		},
		"Rotacja buildu Kapłana z ograniczeniem many przez czas `Balance.bossFight`, leczenie tylko na tanku (bez drugiego celu, innych członków i nadmiaru w tarczę) / `tankDps`; drużyna domyślna W, M, Ł, K, W, drużyna S92: Obrońca, Kapłan buildu, Furia, Królobójca; cel 1,0–2,0 asertują S86 (Grimrok, Łąki) i S92–S94. "
			.. SKILL_NOTE
	)
	for _, build in SkillModel.builds("Cleric") do
		for _, L in LEVELS do
			local bossId = SkillModel.BOSS_AT[L]
			local h = SkillModel.healerVsBoss(build, bossId)
			local h2 = SkillModel.healerVsBoss(build, bossId, { team = "s92" })
			row(`{build.key} · {bossId} ({h.level})`, {
				{ h.tsk6, "2", 1.0, 2.0 },
				{ h2.tsk6, "2", 1.0, 2.0 },
				{ h.hps },
				{ h.tankDps },
				{ h.seconds, "s" },
				{ h.mana, "2" },
			})
		end
	end
	-- Comparisons (H2, H3)
	section(
		"Porównanie z diagnozą i ROZWOJ",
		{ "miara (przyczyna różnicy)", "model", "odniesienie", "różnica" },
		"L20: baza z bronią `Balance.LOADOUT` wobec diagnozy `3f935c1` (plan balansu D1), baza z bronią ROZWOJ wobec ROZWOJ 2.5; P2: ROZWOJ 9.6, 11.6, 12.7. Różnica ponad 10% pogrubiona; przyczyna w etykiecie jest stała (klucz migawki), „–” = bez opisanej przyczyny. Model nie jest strojony pod te liczby (SESJE S85). "
			.. SKILL_NOTE
	)
	local refs = BalanceTables.SKILL_REFERENCES
	local causes = BalanceTables.SKILL_CAUSES
	local function compare(id: string, label: string, model: number, reference: number)
		local diff = model / reference - 1
		-- a fixed label (snapshot key); the 10% verdict is the cell's band
		row(`{label} ({causes[id] or "–"})`, { { model, "2" }, { reference, "2" }, { diff, "%", -0.1, 0.1 } })
	end
	for _, c in B.CLASSES do
		local loadout = SkillModel.build("base.loadout", c) or SkillModel.build("base", c)
		local m = SkillModel.metrics(loadout :: SkillModel.Build, 20)
		compare(`d1.tsk1.{c}`, `D1 T-SK1 {CLASS_PL[c]} L20`, m.tsk1, refs.d1.tsk1[c])
		compare(`d1.tsk2.{c}`, `D1 T-SK2 {CLASS_PL[c]} L20`, m.tsk2, refs.d1.tsk2[c])
		compare(`d1.tsk3.{c}`, `D1 T-SK3 {CLASS_PL[c]} L20`, m.tsk3, refs.d1.tsk3[c])
	end
	local mageLoadout = SkillModel.build("base.loadout", "Mage") :: SkillModel.Build
	compare("d1.tsk4", "D1 T-SK4 Mag L20", SkillModel.metrics(mageLoadout, 20).tsk4, refs.d1.tsk4)
	local clericBase = SkillModel.build("base", "Cleric") :: SkillModel.Build
	compare("d1.tsk5", "D1 T-SK5 Kapłan L20 (tank Wojownik)", SkillModel.oneHeal(clericBase, 20), refs.d1.tsk5)
	compare("d1.tsk6", "D1 T-SK6 Kapłan Grimrok", SkillModel.healerVsBoss(clericBase, "grimrok").tsk6, refs.d1.tsk6)
	for _, c in B.CLASSES do
		local base = SkillModel.build("base", c) :: SkillModel.Build
		compare(
			`rozwoj25.{c}`,
			`ROZWOJ 2.5 T-SK1 {CLASS_PL[c]} L20`,
			SkillModel.metrics(base, 20).tsk1,
			refs.rozwoj25[c]
		)
	end
	local healer = SkillModel.build("healer.dungeon", "Cleric") :: SkillModel.Build
	local fortune = SkillModel.build("fortune.plunder", "Cleric") :: SkillModel.Build
	local hunter = SkillModel.build("base", "Hunter") :: SkillModel.Build
	local mage = SkillModel.build("base", "Mage") :: SkillModel.Build
	for _, L in LEVELS do
		compare(
			"healer96",
			`ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L{L}`,
			SkillModel.oneHeal(healer, L),
			refs.healer96[L]
		)
		compare(
			"fortune96",
			`ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L{L}`,
			SkillModel.oneHeal(fortune, L),
			refs.fortune96[L]
		)
		compare(
			"hunter116",
			`ROZWOJ 11.6 obszar / jeden cel baza Łowcy L{L}`,
			SkillModel.metrics(hunter, L).tsk3,
			refs.hunter116[L]
		)
		if L >= 45 then
			local t4 = SkillModel.metrics(mage, L).tsk4
			compare("mageExp127", `ROZWOJ 12.7 T-SK4 baza Maga (exp) L{L}`, t4, refs.mageExp127[L])
			compare("mageBoss127", `ROZWOJ 12.7 T-SK4 baza Maga (boss) L{L}`, t4, refs.mageBoss127[L])
		end
	end
	BalanceTables.skillSeconds = os.clock() - started
	return tb.tables
end

-- Classes and paths (S86) -------------------------------------------------------------------------------------------

local ItemTraits = require("../src/shared/Data/ItemTraits")

-- S86 (G): builds "do celów" of docs/sessions/S86.md (the guards, situations and the model / ROZWOJ table read them).
BalanceTables.TARGET_BUILDS = {
	Warrior = { "berserker.fury", "guardian.defender", "guardian.loner", "standard.commander" },
	Hunter = { "marksman.kingslayer", "trapper.poacher", "scout.partyHunter" },
	Mage = { "destroyer.destroyerExp", "destroyer.destroyerBoss", "arcanist.arcanistBoss" },
	Cleric = { "inquisitor.solo", "healer.dungeon", "healer.solo", "fortune.plunder" },
} :: { [string]: { string } }

-- S86 (D10): the cause of a model / ROZWOJ difference above ~10% per target id, one phrase (docs/SESJE.md S86 has the
-- full lines); a fixed part of the label (the snapshot key).
BalanceTables.PATH_CAUSES = {
	["berserker.base"] = "Furia krok po kroku, baza z przełomami buildu",
	["guardian.dps"] = "rotacja z danych: okrzyki i ochrona zjadają energię",
	["guardian.ehp"] = "węzły i Furia Strażnika w EHP",
	["guardian.group"] = "Furia Berserkera w grupie, rotacja z danych",
	["standard.support"] = "sztandar raz (opener), Rozkaz bez energii",
	["standard.S"] = "Furia Berserkera",
	["warrior.solo"] = "grupa Furii po S86",
	["inquisitor.ratio"] = "normalizacja broni, Piętno jako podpalenie",
	["healer.dps"] = "rotacja z danych (Sanktuarium tylko w drużynie)",
	["fortune.dps"] = "kości w rotacji, normalizacja",
	["fortune.healLess"] = "węzły leczenia tej kolejności",
	["cleric.solo"] = "walka, w której potwory oddają, i Leczenie między walkami",
	["marksman.base"] = "baza z przełomami Strzelca, cechy broni",
	["marksman.r7"] = "Furia krok po kroku",
	["trapper.aoe"] = "pułapki z danymi S76 (obrażenia, pierścień)",
	["trapper.single"] = "pułapki z obrażeniami na jednym celu",
	["scout.support"] = "Znak i Oznaczenie w modelu",
	["scout.S"] = "Królobójca z cechami",
	["scout.solo"] = "Traper z pułapkami w grupie",
	["destroyer.aoe"] = "próg obszaru i Kaskada w modelu",
	["destroyer.single"] = "baza z przełomami buildu",
	["arcanist.single"] = "Ładunki, Strumień, Wzmocnienie w modelu",
	["arcanist.vsDestroyer"] = "Ładunki, Strumień, Wzmocnienie w modelu",
	["mage.tsk4"] = "koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą",
} :: { [string]: string }

local PATHS_INTRO =
	"S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów."

-- S86 (G): the tables of the section "Klasy i ścieżki" (band "S86-paths"), in report order; every number comes from
-- tests/SkillModel.luau. The values are the fixture tests/fixtures/balance_paths.json.
function BalanceTables.tablesPaths(): { Table }
	local started = os.clock()
	local tb = BalanceTables.builder("S86-paths")
	local section, row = tb.section, tb.row
	local LEVELS = SkillModel.METRIC_LEVELS
	local byKey = SkillModel.byKey

	-- D2: the "Furia" reference
	section(
		"Odniesienie Berserkera „Furia”",
		{
			"poziom",
			"1 cel 60 s",
			"atak podst.",
			"R1",
			"wybuch 8 s",
			"grupa 3 · 8 s",
			"maks. HP",
			"EHP",
			"EHP czerwone",
			"Furia 1 cel",
			"Furia grupa",
			"Furia ROZWOJ",
			"kradzież / obrażenia w grupie",
			"× baza (topór)",
		},
		"Od S89 to liczby zamrożone: dane Berserkera i wspólnej podstawy Wojownika się nie zmieniają (mianownik R7 w S90 i wszystkich klas). Berserker `berserker.fury` z toporem dwuręcznym (ROZWOJ 7.5, 10.4, 10.6): mianownik każdego stosunku „× Berserker”. Furia krok po kroku (`Logic/Fury`, `HOOK_RULES.fury`), średnia stosów obok 7,5 z ROZWOJ 10.6; bilans kradzieży życia w walce z 3 potworami, które oddają (leczenie z kradzieży / przyjęte obrażenia); × baza = 1 cel 60 s / baza Wojownika z toporem. "
			.. PATHS_INTRO
	)
	for _, L in LEVELS do
		local f = SkillModel.furyReference(L)
		row(`L{L}`, {
			{ f.single60 },
			{ f.basic },
			{ f.r1, "2" },
			{ f.burst8 },
			{ f.group },
			{ f.maxHp },
			{ f.ehp },
			{ f.ehpRed },
			{ f.furyMean, "2" },
			{ f.furyMeanGroup, "2" },
			{ 7.5, "1" },
			{ f.lifesteal, "2" },
			{ f.vsBase, "2", 1.25, 1.35 },
		})
	end

	-- E: path targets
	local results = SkillModel.evaluateTargets()
	section(
		"Cele ścieżek: podsumowanie",
		{ "klasa · poziom", "w paśmie", "wierszy" },
		"Wiersze `SkillModel.PATH_TARGETS` (bez R4–R6) na 20 / 45 / 70 / 100; na 20 cele tabeli 1–20 (T-SK3, tempo solo wsparcia i tanka) asertuje blok „Balance 1-20: S91”, reszta to druk (pasma 45–100). Blok „Balance 20-100: paths” w `balance.spec` czyta tę samą `SkillModel.evaluateTargets`. "
			.. PATHS_INTRO
	)
	for _, c in B.CLASSES do
		for _, L in LEVELS do
			local ok, all = 0, 0
			for _, r in results do
				if r.classId == c and r.L == L then
					all += 1
					ok += if r.pass then 1 else 0
				end
			end
			row(`{CLASS_PL[c]} · {L}`, { { ok }, { all } })
		end
	end
	for _, c in B.CLASSES do
		section(
			`Cele ścieżek: {CLASS_PL[c]}`,
			{
				"cel · build · poziom",
				"wartość",
				"mieści się",
				"asertowany",
				"projekt (ROZWOJ)",
				"różnica",
				"źródło",
			},
			"Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; asertowany = 1, gdy blok ścieżek w `balance.spec` sprawdza ten wiersz (S89: Wojownik i Kapłan; wiersz z polem `report` albo poziom z `reportAt` tylko drukowany, kto asertuje w etykiecie); projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). R4 (S89): zysk opcji przełomu na buildzie z `SkillModel.R4_*_BUILDS`, opcje z `R4_UTILITY` i `R4_REPORT` tylko drukowane; R5: największe |broń / średnia − 1|; R6: trzecia część punktów rzędów 4–11 na punkt / średnia (moc z metryki i EHP, L100). "
				.. PATHS_INTRO
		)
		for _, r in results do
			if r.classId == c then
				local note = if r.note then ` ({r.note})` else ""
				local who = if r.report then ` [raport: {r.report}]` else ""
				local label = `{r.id} · {r.build}{note} · {r.L}{who}`
				local src = tonumber(string.match(r.source, "(%d+%.?%d*)")) or 0
				row(label, {
					{ r.value, "2", r.low, r.high },
					{ if r.pass then 1 else 0 },
					{ if r.asserted then 1 else 0 },
					{ r.project or 0 / 0, "2" },
					{ if r.project then r.value / r.project - 1 else 0 / 0, "%", -0.1, 0.1 },
					{ src, "1" },
				})
			end
		end
	end

	-- B: mechanics control cases
	section(
		"Mechaniki: przypadki kontrolne",
		{ "przypadek", "wartość" },
		"Liczby kontrolne mechanik B (testy w bloku „SkillModel: class mechanics (S86)”): kwota Leczenia na „Obrońcy”, kości i koło (`Roll`), podpalenie (Piętno Światła), średnia Furia, pułapki i kontrola, sokół, koszt z Ładunkami, kumulowanie. "
			.. PATHS_INTRO
	)
	do
		local healer = byKey("healer.dungeon")
		row(
			"B1 Leczenie Uzdrowiciela L45 / maks. HP „Obrońcy”",
			{ { SkillModel.oneHeal(healer, 45, SkillModel.defenderTank(45)), "%" } }
		)
		local dice = SkillModel.diceExpected(3, 0, false, 0)
		local double = SkillModel.diceExpected(3, 30, false, 0)
		local wheel = SkillModel.diceExpected(3, 0, true, 50)
		row("B2 kości: ściana (bez rollDouble)", { { dice[1], "2" } })
		row("B2 kości: ściana (rollDouble 30)", { { double[1], "2" } })
		row("B2 koło: ściana (boost 50)", { { wheel[1], "2" } })
		local inq = SkillModel.metrics(byKey("inquisitor.solo"), 45)
		row("B3 Piętno Światła: udział w 1 cel 60 s L45", { { inq.shares.brandOfLight or 0, "%" } })
		for _, L in { 45, 70, 100 } do
			row(`B5 średnia Furia „Furia” L{L} (ROZWOJ 7,5)`, { { SkillModel.fury(L).furyMean, "2" } })
		end
		local poacher = SkillModel.metrics(byKey("trapper.poacher"), 70)
		row("B8 Kłusownik L70: pułapki na minutę", { { poacher.trapsPerMinute, "1" } })
		row("B8 Kłusownik L70: kontrola celu", { { poacher.controlled, "%" } })
		local scout = SkillModel.metrics(byKey("scout.partyHunter"), 70)
		row("B9 Łowczy drużyny L70: uderzenia sokoła na minutę", { { scout.falconPerMinute, "1" } })
		local arc = SkillModel.metrics(byKey("arcanist.arcanistBoss"), 70)
		row("B12 Arkanista L70: średnio Ładunków", { { arc.chargesMean, "2" } })
		local discharge = SkillData.get("arcaneDischarge") :: any
		row(
			"B12 koszt czaru przy 4 Ładunkach / bez (Skills.chargeCostFactor)",
			{ { Skills.chargeCostFactor(4, 0), "2" } }
		)
		row("B12 Wyładowanie przy 4 Ładunkach (Skills.dischargeFactor)", {
			{ Skills.dischargeFactor(Skills.valueAt(discharge, "perCharge", 10), 4), "2" },
		})
		row("B13 kumulowanie: 100 i 100 po 1 s (suma)", { { SkillModel.accumulateCase(100, 100, 1, 4), "i" } })
	end

	-- C3: measured situations
	section(
		"Sytuacje zmierzone (C3)",
		{
			"build · poziom",
			"atak podst. 1 cel",
			"atak podst. grupa",
			"odstęp rzutów s",
			"żywioł broni",
			"lód: kontrola",
			"obszar w grupie",
			"kontrola 1 cel",
			"kontrola boss",
			"bez ruchu",
			"bez ruchu boss",
			"mana (boss 180 s)",
			"leczenie / s tanka",
		},
		`Założenia S84 (Balance.SITUATIONS) w kolumnach obok: atak podst. {B.SITUATIONS.basicShare.Warrior} (Mag {B.SITUATIONS.basicShare.Mage}), odstęp {B.SITUATIONS.skillInterval} s, żywioł {B.SITUATIONS.elementShare}, lód {B.SITUATIONS.iceUptime}, kontrola {B.SITUATIONS.controlled}, bez ruchu {B.SITUATIONS.still}, obszar {B.SITUATIONS.areaShare}. Zmierzone na buildach „do celów” (\`SkillModel.situations\`); \`Balance.traitTerms\` przyjmuje je czwartym argumentem, przełączenie domyślnych sytuacji to decyzja S88. `
			.. PATHS_INTRO
	)
	for _, c in B.CLASSES do
		for _, key in BalanceTables.TARGET_BUILDS[c] do
			for _, L in { 45, 70, 100 } do
				local s = SkillModel.situations(byKey(key), L)
				row(`{key} · {L}`, {
					{ s.basicShare, "%" },
					{ s.basicShareGroup, "%" },
					{ s.skillInterval, "1" },
					{ s.elementShare, "%" },
					{ s.iceUptime, "%" },
					{ s.areaShare, "%" },
					{ s.controlled, "%" },
					{ s.controlledBoss, "%" },
					{ s.still, "%" },
					{ s.stillBoss, "%" },
					{ s.mana or 0 / 0, "%" },
					{ s.dungeon or 0 / 0 },
				})
			end
		end
	end

	-- C6: traits in the skill model
	section(
		"Cechy w modelu umiejętności (C6)",
		{
			"cecha · build · sytuacja · poziom · rzadkość",
			"S84",
			"S84 z sytuacją zmierzoną",
			"model umiejętności",
			"STATY 14",
			"model − STATY",
		},
		"Wartość cechy = M(z) / M(bez) − 1 (definicja S84 / S88): S84 `Balance.traitValue`, ta sama z sytuacją zmierzoną (`traitTerms`, czwarty argument), model umiejętności na zdarzeniu (Fechtunek, Zastawa, Łamanie kości, Nękanie, Wstrząs, Żniwo przez `traitTerms` z sytuacją zmierzoną), szacunek STATY 14. Różnica ponad 1,5 pkt pogrubiona (lista „Dla S88”). Zwykły +0 i Mityczny +9. "
			.. PATHS_INTRO
	)
	for _, L in { 45, 70, 100 } do
		for _, rr in { { 1, 0, "Zwykły +0" }, { 5, 9, "Mityczny +9" } } do
			for _, def in ItemTraits.list do
				local t = SkillModel.traitRow(def.id, L, rr[1], rr[2])
				row(`{def.id} · {t.build} · {t.situation} · {L} · {rr[3]}`, {
					{ t.s84, "%" },
					{ t.measured, "%" },
					{ t.model, "%" },
					{ t.staty, "%" },
					{ t.model - t.staty, "%", -0.015, 0.015 },
				})
			end
		end
	end

	-- F2: guards
	local d1 = SkillModel.GUARD_D1
	section(
		"Strażniki T-SK (F2)",
		{ "build · poziom", "T-SK1 / własne L20", "T-SK2 / własne L20", "T-SK3 / areaCap", "T-SK1 L20", "T-SK2 L20" },
		`\`SkillModel.guards\`: progi ≤ 1,15, ≤ 1,25, ≤ 1,0 (pogrubione ponad); „własne L20” = ten sam build przycięty do L20. Odniesienia L20 planu (D1, sprzed przebudowy): T-SK1 W / Ł / M / K {d1.tsk1.Warrior} / {d1.tsk1.Hunter} / {d1.tsk1.Mage} / {d1.tsk1.Cleric}, T-SK2 {d1.tsk2.Warrior} / {d1.tsk2.Hunter} / {d1.tsk2.Mage} / {d1.tsk2.Cleric}, T-SK3 {d1.tsk3.Warrior} / {d1.tsk3.Hunter} / {d1.tsk3.Mage} / {d1.tsk3.Cleric}. Asertują S92 (25–44), S93 (45–69), S94 (70–100) po kotwicy S91. `
			.. PATHS_INTRO
	)
	for _, c in B.CLASSES do
		local keys = { "base" }
		for _, k in BalanceTables.TARGET_BUILDS[c] do
			table.insert(keys, k)
		end
		for _, key in keys do
			local build = SkillModel.build(key, c) :: SkillModel.Build
			local at20 = SkillModel.metrics(build, 20)
			for _, L in SkillModel.GUARD_LEVELS do
				local g = SkillModel.guards(build, L)
				row(`{c} {key} · {L}`, {
					{ g.tsk1rel, "2", nil, SkillModel.GUARD_LIMITS.tsk1rel },
					{ g.tsk2rel, "2", nil, SkillModel.GUARD_LIMITS.tsk2rel },
					{ g.tsk3cap, "2", nil, SkillModel.GUARD_LIMITS.tsk3cap },
					{ at20.tsk1, "2" },
					{ at20.tsk2, "2" },
				})
			end
		end
	end

	-- F3 / F4
	section(
		"G10 w modelu S86 (F3)",
		{ "wiersz", "wartość", "asertuje S87" },
		"`SkillModel.targetsG10`: T-SK4 z Ładunkami i biernymi zwrotami, T-SK5 z premiami B1; bez pola `report` tylko T-SK4 `destroyer.destroyerExp` i `arcanist.arcanistBoss` oraz T-SK5 `healer.dungeon` na `guardian.defender` (1 w ostatniej kolumnie). "
			.. PATHS_INTRO
	)
	for _, r in SkillModel.targetsG10() do
		row(r.label, { { r.value, "2", r.low, r.high }, { if (r :: any).report == nil then 1 else 0 } })
	end
	section(
		"Łąki na L20 w modelu S86 (F4)",
		{ "wiersz", "wartość", "asertowany" },
		"`SkillModel.targetsMeadows`: wiersze w paśmie asertuje blok regionów (1), reszta drukowana z powodem w kodzie (`MEADOWS_REPORT`, S91: buildy, które nie leczą tanka). "
			.. PATHS_INTRO
	)
	for _, r in SkillModel.targetsMeadows() do
		row(r.label, { { r.value, "2", r.low, r.high }, { if (r :: any).report == nil then 1 else 0 } })
	end

	-- D7: R4 / R5 / R6
	section(
		"R4: wartość opcji przełomu",
		{ "build · umiejętność · ranga · opcja · poziom", "zysk", "w buildzie" },
		"`SkillModel.optionGain`: wartość umiejętności w roli (60 s na odnowieniu, 1 cel albo 3 cele z obrażeniami w czasie; leczenie na „Obrońcy”) z opcją / bez tego przełomu − 1, na pierwszym z 45 / 70 / 100, na którym ranga go ma. Pasma testu (S89): przełom 5 0,08–0,17, przełom 10 0,17–0,28 (ROZWOJ 0: ok. +10–15% / +20–25%); 0 = opcja bez wartości w tej roli (użytkowa, `SkillModel.R4_UTILITY`). Wojownik i Kapłan na wszystkich poziomach: wiersze `r4.*` w „Cele ścieżek”. "
			.. PATHS_INTRO
	)
	for _, r in SkillModel.r4Rows() do
		local band = SkillModel.R4_BANDS[r.at]
		row(`{r.build} · {r.skill} · {r.at} · {r.choice} · {r.L}`, {
			{ r.value, "%", band[1], band[2] },
			{ if r.chosen then 1 else 0 },
		})
	end
	section(
		"R5: rozrzut ścieżek i broni",
		{ "rodzaj · build · broń · poziom", "zysk" },
		"`SkillModel.r5Rows`: (a) ścieżka bojowa w swojej metryce / średnia pary klasy w tej metryce − 1 (Łowca: Strzelec 1 cel, Traper obszar 8 s; Mag: Niszczyciel obszar 60 s, Arkanista boss 180 s); (b) każda broń ścieżki / średnia broni − 1. Pasmo R5 ±10% (ROZWOJ 0; ustalają S89–S90). "
			.. PATHS_INTRO
	)
	for _, r in SkillModel.r5Rows() do
		row(`{r.kind} · {r.build} · {r.weapon} · {r.L}`, { { r.value, "%", -0.1, 0.1 } })
	end
	section(
		"R6: wartość punktu (L100)",
		{ "build · węzeł", "rangi", "zysk na punkt", "× średnia ścieżki" },
		"`SkillModel.r6Rows` (P2): zysk metryki ścieżki z węzła rzędów 4–11 ścieżki głównej (pasywka albo modyfikacja; build bez jego rang) na punkt, wobec średniej węzłów buildu; ROZWOJ 0: „mniej więcej stała” (0 = węzeł bez wartości w tej metryce: obronny albo użytkowy). "
			.. PATHS_INTRO
	)
	for _, r in SkillModel.r6Rows() do
		row(`{r.build} · {r.node}`, { { r.ranks }, { r.perPoint, "%" }, { r.value, "2" } })
	end

	-- E3 Elites
	section(
		"Elity i Elity II (E3)",
		{
			"build · poziom",
			"Elita wygrana",
			"Elita czas s",
			"Elita HP na końcu",
			"Elita II wygrana",
			"Elita II czas s",
			"Elita II HP na końcu",
		},
		"`SkillModel.duel`: pojedynek z miksturami z Elitą i Elitą II regionu poziomu L (jaskinie `Balance.caveElites`, zdolność Elity II), potwór oddaje. Cel ROZWOJ 7.5: Elity wygrane, Elity II przegrane; wynik zależy od kotwic Elit S87 i potworów S92–S94, więc raport. "
			.. PATHS_INTRO
	)
	for _, key in { "guardian.loner", "standard.commander", "healer.solo", "fortune.plunder", "scout.partyHunter" } do
		for _, L in LEVELS do
			local elite, elite2 = SkillModel.eliteKinds(L)
			if elite and elite2 then
				local a = SkillModel.duel(byKey(key), L, elite, "elite")
				local b = SkillModel.duel(byKey(key), L, elite2, "elite2")
				row(`{key} · {L}`, {
					{ if a.won then 1 else 0 },
					{ a.seconds, "s" },
					{ a.hpEnd, "%" },
					{ if b.won then 1 else 0 },
					{ b.seconds, "s" },
					{ b.hpEnd, "%" },
				})
			end
		end
	end

	-- B7 intercept
	section(
		"Przechwyt w modelu bossa (B7)",
		{
			"boss pasma (poziom)",
			"cios w Maga / HP",
			"z Przechwyceniem",
			"z Przechwyceniem i Osłoną",
			"część Strażnika / jego HP",
			"Mur Tarcz bez limitu",
			"Mur Tarcz z limitem",
		},
		"`SkillModel.interceptReport` (`Logic/Intercept`: `resolve`, `part`, `take` z `caps.interceptPerSecond`, `split` z Męczennikiem): największy cios bossa pasma w Maga drużyny domyślnej i czerwona strefa na całą drużynę z Murem Tarcz „Obrońcy”. ROZWOJ 10.6 na L100: cios 115% HP Maga → 80% (z Osłoną 72%), Mur Tarcz bez limitu ok. 116% HP Strażnika, z limitem ok. 74%. "
			.. PATHS_INTRO
	)
	for _, L in LEVELS do
		local r = SkillModel.interceptReport(L)
		row(`{SkillModel.BOSS_AT[L]} ({L})`, {
			{ r.mageHit, "%" },
			{ r.mageKept, "%" },
			{ r.mageCovered, "%" },
			{ r.guardTook, "%" },
			{ r.wallNoCap, "%" },
			{ r.wallCap, "%" },
		})
	end

	-- B2 Fortune
	section(
		"Premia Fortuny dla drużyny (B2)",
		{ "poziom", "kości", "koło", "pech wroga: udział czasu", "pech wroga: średnio %" },
		"`SkillModel.fortuneBonus`: średnie w czasie 180 s ścian kości i koła (krytyk, szybkość ataku) na sojuszniku przeliczone na obrażenia „Furii” i pech (`misfortune`) na bossie. Projekt ROZWOJ 9.6: kości ok. +2%, koło ok. +12% na 10 s co 90 s, wróg chybia do 15%. "
			.. PATHS_INTRO
	)
	for _, L in LEVELS do
		local f = SkillModel.fortuneBonus(byKey("fortune.plunder"), L)
		row(`L{L}`, { { f.dice, "%" }, { f.wheel, "%" }, { f.missUptime, "%" }, { f.missMean, "1" } })
	end

	-- B8.4 traps
	section(
		"Pułapki: model a natychmiastowe koła (B8)",
		{ "build · poziom", "obszar 8 s", "obszar 8 s: koła", "1 cel 60 s", "1 cel 60 s: koła" },
		"„Kłusownik” z pułapkami według `Movement.trap` (sprawdzenie co `TRAP_CHECK`, czekanie na ściągnięcie) i z wyzwoleniem w chwili postawienia (ROZWOJ 11.6, „dla Trapera optymistycznie”). "
			.. PATHS_INTRO
	)
	for _, L in { 45, 70, 100 } do
		local a, b, c, d = SkillModel.trapTiming(byKey("trapper.poacher"), L)
		row(`trapper.poacher · {L}`, { { a }, { b }, { c }, { d } })
	end

	-- B of the support paths
	section(
		"Wsparcie: B na źródła",
		{ "build · poziom · źródło", "B" },
		"Chorąży (`SkillModel.standardSupport`): średnie w czasie premii drużynowych × `ASSUMPTIONS.bannerUptime`, każda przeliczona na obrażenia „Furii”; Zwiadowca (`SkillModel.scoutSupport`): średnia `enemyWeak` na bossie (najsilniejszy wpis). Projekt: Chorąży na 100. Głos 2%, Sztandar 1,8%, Natchnienie 0,7%, Miażdżący Cios 1,5%, Rozkaz 3,5% (× 0,9); Zwiadowca 6 / 6,8 / 9,5% na 45 / 70 / 100. "
			.. PATHS_INTRO
	)
	for _, entry in
		{
			{ "standard.commander", false },
			{ "scout.partyHunter", true },
		}
	do
		for _, L in { 45, 70, 100 } do
			local build = byKey(entry[1])
			local s = if entry[2] then SkillModel.scoutSupport(build, L) else SkillModel.standardSupport(build, L)
			local names = {}
			for name in s.sources do
				table.insert(names, name)
			end
			table.sort(names)
			for _, name in names do
				row(`{entry[1]} · {L} · {name}`, { { s.sources[name], "%" } })
			end
			row(`{entry[1]} · {L} · razem`, { { s.B, "%" } })
		end
	end

	-- S90 (C4, I1): the Hunter's caps after the falling Dexterity
	section(
		"Łowca: Zręczność a limity (S90)",
		{ "build · poziom", "krytyk", "krytyk z Namierzeniem", "obrażenia kryt.", "szybkość ataku", "unik" },
		"`SkillModel.dexCaps`: wartości `StatCalc` przed obcięciem limitem `Data/Stats` (krytyk 60, szybkość 2,5, unik 30), Zręczność z oceną `DEX × min(1, 20/L)`, węzły, pasywki i przedmioty; krytyk z `sighted` Namierzenia na randze buildu. Asercja: wiersze `hunter.dexCaps` w „Cele ścieżek” (nadwyżka ≤ 0,5 pkt, szybkość ≤ 0,01; ROZWOJ 8, 11.6, 15.4). Projekt na 100.: Strzelec krytyk 26 (46 z Namierzeniem), obrażenia krytyczne 195%; Zwiadowca krytyk 23, unik 25, szybkość ×1,35 z Łukiem i ×1,76 z Łukiem Krótkim. "
			.. PATHS_INTRO
	)
	for _, key in
		{
			"marksman.kingslayer",
			"marksman.eliteHunter",
			"trapper.poacher",
			"trapper.poisoner",
			"scout.partyHunter",
			"scout.tracker",
		}
	do
		for _, L in { 20, 45, 70, 100 } do
			local c = SkillModel.dexCaps(byKey(key), L)
			row(`{key} · {L}`, {
				{ c.crit, "1", nil, c.critCap },
				{ c.critSighted, "1", nil, c.critCap },
				{ c.critDmg, "i" },
				{ c.speed, "2", nil, c.speedCap },
				{ c.dodge, "1", nil, c.dodgeCap },
			})
		end
	end

	-- S90 (F4, I1): the Mage's mana
	section(
		"Mag: mana (S90)",
		{
			"build · poziom",
			"zapotrzebowanie / s",
			"regeneracja / s",
			"bierne zwroty / s",
			"T-SK4",
			"Inwokacja / s",
			"T-SK4 z Inwokacją",
		},
		"`SkillModel.manaRow`: zapotrzebowanie = każdy czar z obrażeniami na odnowieniu przez 60 s bez limitu many (koszt przez `Skills.cost` z krzywą `manaCost` i Ładunkami), dochód = regeneracja z węzłami i bierne zwroty (Odzysk, Kaskada z walki z grupą); Inwokacja na każdym odnowieniu osobno (jej % puli / odnowienie). Pasma ROZWOJ 12.0, 12.7 (asertowane w „Cele ścieżek”, `mage.tsk4`, i w G10): Niszczyciel exp 2,0–2,8, boss z Oszczędnym Splotem 1,6–2,8, Arkanista 2,0–2,4, z Przeciążeniem 2,6–2,8; baza 1,1–1,4 tylko druk. "
			.. PATHS_INTRO
	)
	for _, key in
		{
			"base",
			"destroyer.destroyerExp",
			"destroyer.destroyerBoss",
			"arcanist.arcanistBoss",
			"arcanist.arcanistOverload",
		}
	do
		for _, L in { 45, 70, 100 } do
			local m = SkillModel.manaRow(SkillModel.build(key, "Mage") :: SkillModel.Build, L)
			local band = SkillModel.TSK4_BANDS[key] or { 2.0, 3.0 }
			row(`{key} · {L}`, {
				{ m.demand, "1" },
				{ m.regen, "1" },
				{ m.returns, "2" },
				{ m.ratio, "2", band[1], band[2] },
				{ m.evocation, "1" },
				{ m.ratioEvocation, "2" },
			})
		end
	end

	-- S90 (I2): the class base at L20, the input of S91 (ROZWOJ 2.5); S91: the anchor after the retune is "Kotwica L20 (S91)"
	section(
		"Baza na L20 dla S91 (S90)",
		{ "klasa · build", "R1 (T-SK1) na L20", "dziś (2.5)", "projekt przebudowy (2.5)" },
		"Łowca i Mag bez ścieżki głównej na L20 (podstawa na rangach z L20; Salwa i Meteor od 30., Instynkt Drapieżnika i Burza Piorunów od 45.) i każdy build wzorcowy przycięty do L20 (rzędy 1–2 ścieżki, 10 punktów): obrażenia z umiejętności × atak podstawowy (R1) obok „dziś” i projektu z ROZWOJ 2.5. Liczone na bieżących danych (S91 przestroiło rangi ≤ 20; kotwica L20 w tabeli „Kotwica L20 (S91)”). "
			.. PATHS_INTRO
	)
	for _, spec in { { "Hunter", 2.12, 1.97 }, { "Mage", 2.37, 2.22 } } :: { { any } } do
		local c = spec[1]
		for _, build in SkillModel.builds(c) do
			local m = SkillModel.metrics(build, 20)
			row(`{CLASS_PL[c]} · {build.key}`, { { m.r1, "2" }, { spec[2], "2" }, { spec[3], "2" } })
		end
	end

	-- S90 (I1): report-only rows of docs/sessions/S90.md "Tylko raport"
	section(
		"Łowca i Mag: tylko raport (S90)",
		{ "wiersz · poziom", "wartość", "projekt / pasmo" },
		"Pozycje „Tylko raport” S90 (kto asertuje w etykiecie): moc √(1 cel 60 s × EHP) Strzelca wobec „Furii” (G5 0,95–1,10), Traper wobec „Furii” (zwolniony z R7, projekt 1,01–1,10), „Truciciel” na celu bossa 60 s i 180 s wobec bazy z tą samą bronią (stosy trucizny, 11.7 ryzyko 3), EHP Zwiadowcy wobec bazy (projekt 1,17–1,26), Arkanista z Przeciążeniem wobec bazy i Niszczyciela (boss 180 s; projekt na 100. 1,52 i 1,28), udział Strumienia Arkanów (boss 180 s z nim / bez; projekt ×1,03 na 70., ×1,08 na 100.), czas na potwora z odpoczynkiem (baza, Niszczyciel exp, Arkanista; s), rozrzut żywiołów (max / min − 1, 1 cel 60 s i obszar 60 s; lista „Dla właściciela” ponad 15%). T-SK6 z drużyną S92 (Królobójca) w tabeli T-SK6, Elity i Elity II Zwiadowcy w E3, B Zwiadowcy na źródła wyżej, premia za różne klasy w tabelach regionów: asercje w S92–S94. "
			.. PATHS_INTRO
	)
	do
		local fury = SkillModel.FURY
		for _, L in { 20, 45, 70, 100 } do
			local f = SkillModel.metrics(byKey(fury), L)
			local function power(m: any): number
				return math.sqrt(m.single60 * m.ehp)
			end
			for _, w in { "longbow", "heavycrossbow" } do
				local b = SkillModel.withWeapon(byKey("marksman.kingslayer"), w, "quiver")
				local m = SkillModel.metrics(b, L)
				row(`moc Strzelca ({w}) / Furia · {L} [raport: S92–S94]`, {
					{ power(m) / power(f), "2", 0.95, 1.10 },
					{ 0 / 0, "2" },
				})
			end
			for _, w in { "crossbow", "bow" } do
				local b = SkillModel.withWeapon(byKey("trapper.poacher"), w, "quiver")
				row(`Traper ({w}) / Furia, 1 cel 60 s · {L} [zwolniony z R7]`, {
					{ SkillModel.metrics(b, L).single60 / f.single60, "2", 1.01, 1.10 },
					{ 0 / 0, "2" },
				})
			end
			local poisoner = byKey("trapper.poisoner")
			local pBase = SkillModel.baseFor(poisoner)
			local function onBoss(build: SkillModel.Build, seconds: number): number
				local sp = SkillModel.player(build, L)
				return SkillModel.fight(sp, { seconds = seconds, targets = { B.monster(B.GENERIC, L, "boss") } }).dps
			end
			row(`Truciciel / baza, boss 60 s · {L} [raport]`, {
				{ onBoss(poisoner, 60) / onBoss(pBase, 60), "2" },
				{ 0 / 0, "2" },
			})
			row(`Truciciel / baza, boss 180 s · {L} [raport]`, {
				{ onBoss(poisoner, 180) / onBoss(pBase, 180), "2" },
				{ 0 / 0, "2" },
			})
			local scout = byKey("scout.partyHunter")
			row(`EHP Zwiadowcy / bazy · {L} [raport]`, {
				{ SkillModel.metrics(scout, L).ehp / SkillModel.metrics(SkillModel.baseFor(scout), L).ehp, "2" },
				{ 1.2, "2" },
			})
			local over = SkillModel.metrics(byKey("arcanist.arcanistOverload"), L)
			local overBase = SkillModel.metrics(SkillModel.baseFor(byKey("arcanist.arcanistOverload")), L)
			local dBoss = SkillModel.metrics(byKey("destroyer.destroyerBoss"), L)
			row(`Przeciążenie / baza, boss 180 s · {L} [raport]`, {
				{ over.boss180 / overBase.boss180, "2" },
				{ if L == 100 then 1.52 else 0 / 0, "2" },
			})
			row(`Przeciążenie / Niszczyciel (boss) · {L} [raport]`, {
				{ over.boss180 / dBoss.boss180, "2" },
				{ if L == 100 then 1.28 else 0 / 0, "2" },
			})
			if L >= 60 then
				local arc = byKey("arcanist.arcanistBoss")
				row(`udział Strumienia (z / bez), boss 180 s · {L} [raport]`, {
					{
						SkillModel.metrics(arc, L).boss180
							/ SkillModel.metrics(SkillModel.withoutSkill(arc, "arcaneTorrent"), L).boss180,
						"2",
					},
					{ if L == 70 then 1.03 elseif L == 100 then 1.08 else 0 / 0, "2" },
				})
			end
			if L >= 45 then
				for _, key in { "destroyer.destroyerExp", "arcanist.arcanistBoss" } do
					row(`czas na potwora z odpoczynkiem: {key} · {L} [raport]`, {
						{ SkillModel.restPerMonster(byKey(key), L), "1" },
						{ 0 / 0, "2" },
					})
				end
				row(`czas na potwora z odpoczynkiem: baza · {L} [raport]`, {
					{ SkillModel.restPerMonster(SkillModel.baseFor(byKey("destroyer.destroyerExp")), L), "1" },
					{ 0 / 0, "2" },
				})
				for _, key in { "destroyer.destroyerExp", "arcanist.arcanistBoss" } do
					local m = SkillModel.metrics(byKey(key), L)
					for _, field in { "single60", "aoe3sus" } do
						local lo, hi = math.huge, 0
						for _, e in m.byElement or {} do
							local v = (e :: any)[field]
							lo, hi = math.min(lo, v), math.max(hi, v)
						end
						row(`rozrzut żywiołów {key} {field} · {L} [właściciel]`, {
							{ hi / math.max(1e-9, lo) - 1, "%", nil, 0.15 },
							{ 0 / 0, "2" },
						})
					end
				end
			end
		end
	end

	-- D10: model and ROZWOJ
	section(
		"Model a ROZWOJ (D10)",
		{ "cel · build · poziom (przyczyna)", "model", "projekt", "różnica" },
		"Wiersze celów z liczbą z tabeli ROZWOJ (9.6, 10.6, 11.6, 12.7) dla tego samego buildu i poziomu; różnica ponad 10% pogrubiona, przyczyna w etykiecie (stała, klucz migawki) i w SESJE S86. Model jest prawdą, chyba że różnica wskazała błąd odwzorowania serwera. "
			.. PATHS_INTRO
	)
	for _, r in results do
		if r.project then
			row(
				`{r.id} · {r.build} · {r.L}{if r.note then ` ({r.note})` else ""} ({BalanceTables.PATH_CAUSES[r.id] or "–"})`,
				{
					{ r.value, "2" },
					{ r.project, "2" },
					{ r.value / r.project - 1, "%", -0.1, 0.1 },
				}
			)
		end
	end
	BalanceTables.pathSeconds = os.clock() - started
	return tb.tables
end

-- Paths fixture (S86 H1) --------------------------------------------------------------------------------------------

BalanceTables.PATHS_FIXTURE_PATH = "tests/fixtures/balance_paths.json"
-- Modules the S86 skill model reads (dataHash): a change in any of them may change the tables (S87 and later).
BalanceTables.PATH_MODEL_MODULES = {
	"Skills/Cleric",
	"Skills/Hunter",
	"Skills/Mage",
	"Skills/Warrior",
	"Skills/init",
	"Paths/Cleric",
	"Paths/Hunter",
	"Paths/Mage",
	"Paths/Warrior",
	"Paths/init",
	"SkillCurves",
	"LevelCurves",
	"Classes",
	"Combat",
	"BuffCategories",
	"Stats",
	"ItemTraits",
	"Items/Bases",
	"Items/Consumables",
	"Bonuses",
	"Rarities",
	"Monsters",
	"MonsterAbilities",
	"Bosses",
	"Families",
	-- read too: hit delays (SkillMotions.hitDelay), the Elite caves and the region kinds (Balance.caveElites,
	-- kindAtRegion; the Areas modules hash their picked numbers), STATY 14 of the trait table (ItemWeights)
	"SkillMotions",
	"Areas/Caves",
	"Areas/meadows",
	"Areas/duskwood",
	"Areas/frostpeak",
	"Areas/ashen",
	"AreaProfiles",
	"ItemWeights",
	"Config",
}

-- dataHash of a fixture: per module, FNV-1a of the sorted "key=%.10g" lines of its Balance.dataDump part (the
-- entries of tools/balance_reasons.luau; Config with CONFIG_KEYS and `configExtra`).
function BalanceTables.dataHashOf(modules: { string }, configExtra: { string }): { [string]: string }
	local Reasons = (require :: any)("../tools/balance_reasons")
	local entries = {}
	for _, name in modules do
		if name ~= "Config" then
			local path = `Data/{name}`
			local found: any = { path = path }
			for _, entry in Reasons.BALANCE_MODULES do
				if entry.path == path then
					found = entry
				end
			end
			table.insert(entries, found)
		end
	end
	local config = table.clone(Reasons.CONFIG_KEYS)
	for _, key in configExtra do
		table.insert(config, key)
	end
	local skipped = B.skippedFunctions
	local dump = B.dataDump({ BALANCE_MODULES = entries, CONFIG_KEYS = config, NOT_BALANCE = {}, reasons = {} })
	B.skippedFunctions = skipped
	local lines: { [string]: { string } } = {}
	for key, v in dump do
		local module = string.match(key, "^([^:]+):") :: string
		lines[module] = lines[module] or {}
		table.insert(lines[module], `{key}={string.format("%.10g", v)}`)
	end
	local out: { [string]: string } = {}
	for _, name in modules do
		local list = lines[name] or {}
		table.sort(list)
		out[name] = string.format("%08x", BalanceTables.fnv1a(table.concat(list, "\n")))
	end
	return out
end

function BalanceTables.pathDataHash(): { [string]: string }
	return BalanceTables.dataHashOf(BalanceTables.PATH_MODEL_MODULES, { "Skills" })
end

function BalanceTables.readPathsFixture(): any?
	if not fs.isFile(BalanceTables.PATHS_FIXTURE_PATH) then
		return nil
	end
	return serde.decode("json", fs.readFile(BalanceTables.PATHS_FIXTURE_PATH))
end

-- The S86 tables against tests/fixtures/balance_paths.json (the shape of itemsFixtureDiff).
function BalanceTables.pathsFixtureDiff(now: { [string]: number }?, tolerance: number?): ItemsFixtureReport
	local file = BalanceTables.readPathsFixture()
	local before: { [string]: number } = if file then file.values or {} else {}
	local values = now or BalanceTables.values(BalanceTables.tablesPaths())
	local tol = tolerance
		or (if file and file.meta then file.meta.tolerance else nil)
		or BalanceTables.FIXTURE_TOLERANCE
	local hash = BalanceTables.pathDataHash()
	local changed: { string } = {}
	for _, name in BalanceTables.PATH_MODEL_MODULES do
		if not file or not file.dataHash or file.dataHash[name] ~= hash[name] then
			table.insert(changed, name)
		end
	end
	local diffs: { FixtureDiff } = {}
	local missing: { string } = {}
	local added: { string } = {}
	local count = 0
	for key, b in before do
		count += 1
		local a = values[key]
		if a == nil then
			table.insert(missing, key)
		else
			local rel = BalanceTables.relative(a, b)
			if rel > tol then
				table.insert(diffs, { key = key, before = b, after = a, rel = rel, allowed = false })
			end
		end
	end
	for key in values do
		if before[key] == nil then
			table.insert(added, key)
		end
	end
	table.sort(diffs, function(x, y)
		if x.rel ~= y.rel then
			return x.rel > y.rel
		end
		return x.key < y.key
	end)
	table.sort(missing)
	table.sort(added)
	return {
		found = file ~= nil,
		sameData = file ~= nil and #changed == 0,
		changedModules = changed,
		count = count,
		diffs = diffs,
		missing = missing,
		added = added,
	}
end

-- 1-20 fixture (S83) --------------------------------------------------------------------------------------------

BalanceTables.FIXTURE_PATH = "tests/fixtures/balance_1_20.json"
BalanceTables.FIXTURE_TOLERANCE = 0.005
-- S91: levels 1-20 are frozen. Every future difference is an entry here (key -> before = fixture, after = now, why)
-- and a DECYZJE line; read by balance1_20.spec and by G12 (Balance.targetsGlobal, tools/balance_report).
export type AllowedDiff = { before: number, after: number, why: string }
-- S109: new 1-20 baseline (quests S95-S109). Every future difference is an entry here (key, before, after, why)
-- and a line in DECYZJE.
BalanceTables.ALLOWED_1_20_DIFFS = {} :: { [string]: AllowedDiff }

-- The fixture file ({ meta, values }) or nil.
function BalanceTables.readFixture(): any?
	if not fs.isFile(BalanceTables.FIXTURE_PATH) then
		return nil
	end
	return serde.decode("json", fs.readFile(BalanceTables.FIXTURE_PATH))
end

function BalanceTables.relative(a: number, b: number): number
	return math.abs(a - b) / math.max(math.abs(b), 1e-9)
end

-- Current 1-20 values (fixtureOnly) against the fixture; `allowed` keys count as allowed differences.
function BalanceTables.fixtureDiff(allowed: { [string]: any }?, tolerance: number?): FixtureReport
	local file = BalanceTables.readFixture()
	local before: { [string]: number } = if file then file.values or {} else {}
	local now = BalanceTables.values(BalanceTables.tables1_20(), true)
	local tol = tolerance or BalanceTables.FIXTURE_TOLERANCE
	local diffs: { FixtureDiff } = {}
	local missing: { string } = {}
	local count, added, unexpected = 0, 0, 0
	for key, b in before do
		count += 1
		local a = now[key]
		if a == nil then
			table.insert(missing, key)
		else
			local rel = BalanceTables.relative(a, b)
			if rel > tol then
				local ok = allowed ~= nil and allowed[key] ~= nil
				unexpected += if ok then 0 else 1
				table.insert(diffs, { key = key, before = b, after = a, rel = rel, allowed = ok })
			end
		end
	end
	for key in now do
		if before[key] == nil then
			added += 1
		end
	end
	table.sort(diffs, function(x, y)
		if x.rel ~= y.rel then
			return x.rel > y.rel
		end
		return x.key < y.key
	end)
	table.sort(missing)
	return {
		found = file ~= nil,
		count = count,
		diffs = diffs,
		missing = missing,
		added = added,
		unexpected = unexpected,
	}
end

-- Items, loot and monster defence 20-100 (S84) ------------------------------------------------------------------

local RARITY_PL = { "Zwykły", "Unikatowy", "Heroiczny", "Legendarny", "Mityczny" }
BalanceTables.RARITY_PL = RARITY_PL
-- Section titles of the four S84 bands (the report prints them after the S83 bands).
BalanceTables.ITEM_BANDS = {
	{
		band = "S84-items",
		title = "Przedmioty 20–100 (S84)",
		intro = "Zysk mocy z rzadkości (G7), parytet broni dwuręcznej (G8), wartość cech broni i ranking broni Łowcy w konwencji S32 (pełny zestaw, ilvl = poziom − 2, oczekiwane linie), z cechami jako wartościami oczekiwanymi w sytuacjach ze STATY 14 (`Balance.SITUATIONS`); G7 asertuje S87 na kolumnie „z cechami”, G8 S87 na „bez cech” (z cechami nie ponad pasmo), wartości cech S88.",
	},
	{
		band = "S84-upgrades",
		title = "Ulepszenia i materiały (S84)",
		intro = "Koszt ulepszeń z `Upgrade.cost` i `Upgrade.chance` wobec dochodu poziomu z modelu S83 (G9, asertuje S87: +1…+3 / dochód i +1…+9 z ochroną samym złotem), popyt i podaż materiałów, godziny na +9 i Rdzenie Legendy (raport dla S87).",
	},
	{
		band = "S84-loot",
		title = "Łup i szczęście (S84)",
		intro = "Drop na godzinę przez `AreaRates.itemsPerKill`, `Logic/Luck` i udział przedmiotów dla klasy (`Balance.usableShare`, odwzorowanie `Loot.pickItem`) w tempie S83, z profilami szczęścia K0–K3 z Fortuną i bez (D5: K0 bez Fortuny, asertują S92–S94 w bloku regionów; szczęście S88), boss z Fortuną, luki poziomu przedmiotów i trwałość.",
	},
	{
		band = "S84-defence",
		title = "Rodziny i obrona potworów (S84)",
		intro = "Udział pancerza i odporności magicznej (`Damage.reduction`) potworów z cechami obrony rodzin (`Data/Families`) i bossów, walka 1 na 1 gracza ze zwykłym zestawem, wpływ uniku i kompensaty życia (S66) oraz zysk z Niszczenia pancerza, Bełtu i linii przebicia (asertuje S88).",
	},
}

-- The S84 tables (bands "S84-items", "S84-upgrades", "S84-loot", "S84-defence"), in report order.
function BalanceTables.tablesItems(): { Table }
	local out: { Table } = {}
	local function band(name: string): (any, any)
		local tb = BalanceTables.builder(name)
		return tb, function()
			for _, t in tb.tables do
				table.insert(out, t)
			end
		end
	end

	-- Items ------------------------------------------------------------------------------------------------------
	local tb, flush = band("S84-items")
	for _, c in B.CLASSES do
		tb.section(
			`G7: zysk mocy z rzadkości, {CLASS_PL[c]}`,
			{ "poziom · rzadkość", "S32", "bez cech", "z cechami", "sama baza", "same linie" },
			"Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu."
		)
		for _, L in B.GLOBAL_LEVELS do
			for rarity = 2, 5 do
				local g = B.rarityGainAt(c, L, rarity)
				local low, high = B.g7Band(c, L, rarity)
				tb.row(`{L} · {RARITY_PL[rarity]}`, {
					{ g.s32, "%", low, high },
					{ g.noTraits, "%", low, high },
					{ g.traits, "%", low, high },
					{ g.baseOnly, "%" },
					{ g.linesOnly, "%" },
				})
			end
		end
	end
	for _, pair in B.G8_PAIRS do
		tb.section(
			`G8: {CLASS_PL[pair.classId]} {pair.weapon} wobec zestawu domyślnego`,
			{
				"rzadkość · ulepszenie · poziom",
				"S32",
				"bez cech (MIX)",
				"z cechami (MIX)",
				"single",
				"group",
				"elite",
				"boss",
				"najgorsza",
			},
			"moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06)."
		)
		for _, rarity in B.GEAR_RARITIES do
			for _, up in { 0, 9 } do
				for _, L in B.ITEM_LEVELS do
					local low, high = B.g8Band(pair.weapon, up)
					local nt = B.twoHandedParity(pair.classId, L, pair.weapon, rarity, up, { traits = false })
					local t = B.twoHandedParity(pair.classId, L, pair.weapon, rarity, up)
					tb.row(`{RARITY_PL[rarity]} · +{up} · {L}`, {
						{ B.twoHandedS32(pair.classId, L, pair.weapon, rarity, up), "2", low, high },
						{ nt.mix, "2", low, high },
						{ t.mix, "2", low, high },
						{ t.single, "2" },
						{ t.group, "2" },
						{ t.elite, "2" },
						{ t.boss, "2" },
						{ t.worst, "2" },
					})
				end
			end
		end
	end
	tb.section(
		"G8: broń dwuręczna wobec zestawu jednoręcznego tej samej ścieżki (raport)",
		{ "broń · zestaw ścieżki · rzadkość · poziom", "bez cech (MIX)", "z cechami (MIX)" },
		"Dla S89–S90: moc² w MIX wobec jednoręcznej z drugą ręką tej samej ścieżki (Niszczyciel: różdżka + kula, Arkanista: różdżka + księga, Uzdrowiciel: berło + tarcza)."
	)
	for _, pair in B.G8_PAIRS do
		local path = pair.path
		if path then
			for _, spec in { { 1, 0 }, { 5, 9 } } do
				for _, L in B.ITEM_LEVELS do
					local rarity, up = spec[1], spec[2]
					local nt =
						B.twoHandedParity(pair.classId, L, pair.weapon, rarity, up, { traits = false, ref = path })
					local t = B.twoHandedParity(pair.classId, L, pair.weapon, rarity, up, { ref = path })
					tb.row(
						`{pair.weapon} · {path.weapon} + {path.offhand} · {RARITY_PL[rarity]} +{up} · {L}`,
						{ { nt.mix, "2" }, { t.mix, "2" } }
					)
				end
			end
		end
	end
	local hunterColumns = { "rzadkość · poziom" }
	for _, w in B.HUNTER_WEAPONS do
		table.insert(hunterColumns, w)
	end
	tb.section(
		"Bronie Łowcy z kołczanem (MIX, moc² / Łuk)",
		hunterColumns,
		"Łowca nie ma broni dwuręcznej (poza G8): ranking pięciu broni z kołczanem z cechami w MIX wobec Łuku, cały zestaw tej samej rzadkości i ulepszenia (dla S90)."
	)
	for _, spec in { { 1, 0 }, { 5, 9 } } do
		for _, L in B.ITEM_LEVELS do
			local rarity, up = spec[1], spec[2]
			local bow = B.powerMix(B.itemPlayer("Hunter", L, { weapon = "bow", rarity = rarity, up = up }))
			local cells: { { any } } = {}
			for _, w in B.HUNTER_WEAPONS do
				local p = B.itemPlayer("Hunter", L, { weapon = w, rarity = rarity, up = up })
				table.insert(cells, { (B.powerMix(p) / bow) ^ 2, "2" })
			end
			tb.row(`{RARITY_PL[rarity]} +{up} · {L}`, cells)
		end
	end
	local traitColumns = { "cecha · poziom (klasa, zestaw)" }
	for _, name in B.SITUATION_LIST do
		table.insert(traitColumns, name)
	end
	table.insert(traitColumns, "MIX")
	table.insert(traitColumns, "zestaw bez cech (MIX)")
	table.insert(traitColumns, "STATY 14")
	for _, spec in { { 1, 0 }, { 5, 9 } } do
		local rarity, up = spec[1], spec[2]
		tb.section(
			`Cechy broni: {RARITY_PL[rarity]} +{up}`,
			traitColumns,
			"Wartość cechy = M(z cechą) / M(bez niej) − 1 (`Balance.traitValue`; druga cecha zestawu zostaje): moc² w sytuacjach mocy i w MIX, EHP w `tank`, utrata HP na zabicie w `solo` (bez / z − 1); puste = sytuacja spoza wiersza STATY 14. Zestaw: klasa i ścieżka z kolumny STATY 3. „Zestaw bez cech”: obie cechy zestawu razem (wobec `NO_TRAITS`). Iskra i Moc żywiołu: średnia żywiołów i każdy osobno. STATY 14: szacunek startowy z `Data/ItemWeights` (bez węzłów)."
		)
		for _, L in B.ITEM_LEVELS do
			for _, r in B.traitTable(L, rarity, up) do
				local cells: { { any } } = {}
				for _, name in B.SITUATION_LIST do
					table.insert(cells, { r.values[name], "%" })
				end
				table.insert(cells, { r.values.mix, "%" })
				table.insert(cells, { r.setNoTraits, "%" })
				table.insert(cells, { r.staty, "%" })
				local element = if r.element then ` ({r.element})` else ""
				tb.row(`{r.traitId}{element} · {L} ({CLASS_PL[r.classId]}, {r.set})`, cells)
			end
		end
	end
	local behinds = table.clone(B.SITUATIONS.behindReport)
	table.insert(behinds, 2, B.SITUATIONS.behindShare)
	local runColumns = { "rzadkość · poziom" }
	for _, situation in { "group", "boss" } do
		for _, behind in behinds do
			table.insert(runColumns, `{situation} {behind}`)
		end
	end
	tb.section(
		"Przeszycie: udział trafień z wrogiem w pasie za celem",
		runColumns,
		"Wartość Przeszycia (`Balance.runThroughValue`, moc² jak w tabeli cech) przy `behindShare` 0,15, 0,3 (model) i 0,5: wymiary pasa czekają na pomiar właściciela. Na bossie udział mnoży się przez czas fal tarczy."
	)
	for _, spec in { { 1, 0 }, { 5, 9 } } do
		local rarity, up = spec[1], spec[2]
		for _, L in B.ITEM_LEVELS do
			local cells: { { any } } = {}
			for _, situation in { "group", "boss" } do
				for _, behind in behinds do
					table.insert(cells, { B.runThroughValue(L, rarity, up, behind, situation), "%" })
				end
			end
			tb.row(`{RARITY_PL[rarity]} +{up} · {L}`, cells)
		end
	end
	flush()

	-- Upgrades and materials ------------------------------------------------------------------------------------
	tb, flush = band("S84-upgrades")
	tb.section(
		"G9: ulepszenia broni wobec dochodu poziomu",
		{
			"klasa · poziom",
			"dochód poziomu",
			"+1…+3 / dochód",
			"+1…+6 / dochód",
			"+1…+9 z ochroną (poziomy)",
			"+1…+9 bez ochrony (poziomy)",
			"zestaw +9 bez ochrony (poziomy)",
			"goldEq +9 z ochroną (poziomy)",
			"zwoje +9",
		},
		"Broń domyślna klasy z ilvl poziom − 2, Zwykła. Dochód poziomu (`Balance.levelIncome`) = (złoto z zabić + sprzedaż dropu na godzinę, `economyAt`) × godziny poziomu (S103: zabicia poziomu z modelu okien, te same, które trzyma kompensacja S98), ze złotem zadań pasma rozłożonym na jego poziomy według potrzebnego EXP (jak dochód S32 i diagnoza). Złoto: porażka powtarza krok (jak `upgradeGold`); bez ochrony: łańcuch Markowa z cofnięciem o poziom; goldEq: złoto + zwoje + materiały (pył ze sklepu, odłamek i kryształ z przetopienia). Cel G9: +1…+3 0,45–1,05; +1…+9 z ochroną 12–25 poziomów."
	)
	for _, L in B.GLOBAL_LEVELS do
		for _, u in B.upgradeVsIncome(L) do
			tb.row(`{CLASS_PL[u.classId]} · {L}`, {
				{ u.income, "i" },
				{ u.up3, "2", 0.45, 1.05 },
				{ u.up6, "2" },
				{ u.up9, "1", 12, 25 },
				{ u.up9Unprotected, "1" },
				{ u.set9Unprotected, "i" },
				{ u.goldEq9, "1" },
				{ u.scrolls9, "1" },
			})
		end
	end
	tb.section(
		"Koszt +1…+9 jednej broni (Legendarnej, ilvl = poziom − 2)",
		{
			"poziom · wariant",
			"złoto",
			"próby",
			"pył",
			"odłamki",
			"kryształy",
			"Rdzenie",
			"Rdzenie od +8 (S87)",
			"zwoje",
			"złoto zwojów",
			"złoto materiałów",
			"goldEq",
			"udział materiałów",
		},
		"`Balance.upgradePlan`. Rdzeń Legendy na każdą próbę od progu `Upgrade.cost` (dziś +7); „od +8” podmienia tylko wynik `Upgrade.cost` w modelu (bez zmiany danych). Zwój na każdą próbę kroku z szansą poniżej 100% (`BlacksmithService.upgrade`). Udział materiałów = złoto materiałów / (złoto + złoto materiałów)."
	)
	for _, L in B.ITEM_LEVELS do
		local ilvl = math.max(1, L - B.GEAR_GAP)
		local item = B.makeItem(B.tierId("sword1h", ilvl), ilvl, 4, 0, {})
		for _, protect in { true, false } do
			local plan = B.upgradePlan(item, 9, protect)
			local core8 = B.upgradePlan(item, 9, protect, { coreFrom = 8 })
			tb.row(`{L} · {if protect then "z ochroną" else "bez ochrony"}`, {
				{ plan.gold, "i" },
				{ plan.attempts, "1" },
				{ plan.materials.essence_dust or 0, "1" },
				{ plan.materials.essence_shard or 0, "1" },
				{ plan.materials.essence_crystal or 0, "1" },
				{ plan.cores, "1" },
				{ core8.cores, "1" },
				{ plan.scrolls, "1" },
				{ plan.scrollGold, "i" },
				{ plan.materialGold, "i" },
				{ plan.goldEq, "i" },
				{ plan.materialGold / (plan.gold + plan.materialGold), "%" },
			})
		end
	end
	tb.section(
		"Popyt na materiały (+6 i +9)",
		{
			"rzadkość · przedmioty · cel · wariant",
			"pył",
			"odłamki",
			"kryształy",
			"Rdzenie",
			"zwoje",
			"odłamki na zwoje",
		},
		"Z `Balance.upgradePlan` (materiały nie zależą od ilvl). Zestaw z jednoręczną: 10 przedmiotów, z dwuręczną: 9. Zwój ochrony z receptury `scroll_protection` (2 odłamki, 2 księżycowe płatki, 2000 złota)."
	)
	for _, need in B.materialDemand() do
		tb.row(need.label, {
			{ need.dust, "1" },
			{ need.shards, "1" },
			{ need.crystals, "1" },
			{ need.cores, "1" },
			{ need.scrolls, "1" },
			{ need.scrollShards, "1" },
		})
	end
	tb.section(
		"Podaż materiałów (Wojownik)",
		{ "poziom · źródło", "pył", "odłamki", "kryształy", "zwoje", "Rdzenie" },
		"Wartości oczekiwane z tabel łupu (szansa × średnia ilość, jak `Loot.rollMonsterLoot`) w tempie S83: expienie (`paceAt`, materiały zabić i rozbiórka wszystkich przedmiotów), Elity w jaskini poziomu (`elitesPerHour`), Elita II na zabicie i na godzinę jednego odrodzenia (`AreaSpawns.elite2Respawn`), boss regionu (`Config.Boss.dailyRuns` × 7 zabić, same materiały)."
	)
	local supplies: { [number]: any } = {}
	for _, L in B.ITEM_LEVELS do
		local s = B.materialSupply("Warrior", L)
		supplies[L] = s
		for _, source in
			{
				{ "expienie / h", s.normal, 1 },
				{ "Elity / h", s.elite, 1 },
				{ "Elita II / zabicie", s.elite2, 1 },
				{ "Elita II / h odrodzeń", s.elite2, s.elite2PerHour },
				{ "boss / tydzień", s.bossWeek, 1 },
			}
		do
			local t = source[2] :: { [string]: number }
			local mul = source[3] :: number
			tb.row(`{L} · {source[1]}`, {
				{ (t.essence_dust or 0) * mul, "1" },
				{ (t.essence_shard or 0) * mul, "2" },
				{ (t.essence_crystal or 0) * mul, "2" },
				{ (t.scroll_protection or 0) * mul, "2" },
				{ (t.legend_core or 0) * mul, "2" },
			})
		end
	end
	tb.section(
		"Godziny na +9 broni, Rdzenie i zwoje (Wojownik)",
		{
			"poziom",
			"h expienia +9 z ochroną",
			"h expienia +9 bez ochrony",
			"h Elit +9 z ochroną",
			"h Elit +9 bez ochrony",
			"Rdzenie / tydzień (boss)",
			"Rdzenie na Legendę +9 z ochroną",
			"zwoje / Elita II",
			"zwoje na +9 z ochroną",
			"udział materiałów w goldEq +9 bez ochrony",
		},
		"Godziny: materiały +9 jednej broni (odłamki zwojów z receptury przy ochronie) z podaży źródła z przetopieniem `Data/Recipes` (10 pyłu → odłamek od 20., 8 odłamków → kryształ od 45.; poniżej 45. kryształy tylko z łupu; „–” = źródło nie daje potrzebnego materiału). Udział materiałów jak diagnoza (75% na ilvl 18, 5% na 98)."
	)
	local demand: { [string]: any } = {}
	for _, need in B.materialDemand() do
		demand[need.label] = need
	end
	for _, L in B.ITEM_LEVELS do
		local s = supplies[L]
		local prot = demand["legendary · broń · +9 · z ochroną"]
		local unprot = demand["legendary · broń · +9 · bez ochrony"]
		local ilvl = math.max(1, L - B.GEAR_GAP)
		local item = B.makeItem(B.tierId("sword1h", ilvl), ilvl, 1, 0, {})
		local plan = B.upgradePlan(item, 9, false)
		tb.row(tostring(L), {
			{ B.materialHours(prot, s.normal, L), "1" },
			{ B.materialHours(unprot, s.normal, L), "1" },
			{ B.materialHours(prot, s.elite, L), "1" },
			{ B.materialHours(unprot, s.elite, L), "1" },
			{ s.bossWeek.legend_core or 0, "2" },
			{ prot.cores, "1" },
			{ s.elite2.scroll_protection or 0, "2" },
			{ prot.scrolls, "1" },
			{ plan.materialGold / (plan.gold + plan.materialGold), "%" },
		})
	end
	flush()

	-- Loot and luck ---------------------------------------------------------------------------------------------
	tb, flush = band("S84-loot")
	tb.section(
		"Profile szczęścia (Kapłan Fortuny: berło + relikwia)",
		{
			"profil · poziom",
			"linie dropBonus",
			"leg_dropBonus",
			"błogosławieństwo",
			"gildia",
			"relikwia",
			"osobiste (dropBonus)",
			"Fortuna (monsterItem)",
			"suma przed limitem",
			"itemBonus",
			"ucięte przez limit",
		},
		"`Balance.LUCK_PROFILES`; liczby z `Bonuses`, `Blessings`, `GuildSkills` i `ItemRoll.trait`. Fortuna = `Paths.luckOfNodes` węzłów szczęścia ścieżki Fortuny na randze maks. jako drugi `Member` z `luck`; `Luck.monster` przycina do `Data/Luck.monsterItemCap` (model niczego nie przycina sam). Cel (S88): K1 i K2 z Fortuną ≤ 100."
	)
	for _, profile in B.LUCK_PROFILES do
		for _, L in { 25, 45, 70, 100 } do
			local lp = B.luckProfile(profile.id, L)
			local luck = B.monsterLuck(profile.id, L, "full")
			tb.row(`{profile.id} ({profile.label}) · {L}`, {
				{ lp.lines, "1" },
				{ lp.legendary, "1" },
				{ lp.blessing, "1" },
				{ lp.guild, "1" },
				{ lp.relic, "1" },
				{ luck.personal, "1" },
				{ luck.fortune, "1" },
				{
					luck.personal + luck.fortune,
					"1",
					nil,
					if profile.id == "K1" or profile.id == "K2" then 100 else nil,
				},
				{ luck.itemBonus, "1" },
				{ luck.personal + luck.fortune - luck.itemBonus, "1" },
			})
		end
	end
	tb.section(
		"Pola szczęścia Fortuny (`Paths.luckOfNodes`)",
		{
			"wariant",
			"monsterItem",
			"elite2",
			"gold",
			"bossLegendary",
			"bossUpgrade",
			"bossExtra",
		},
		"Pełna Fortuna: wszystkie węzły szczęścia ścieżki `fortune` na randze maks.; początek: tylko rzędy otwarte poza ścieżką główną (`DIP_ROWS`). ROZWOJ 6.3: +30 / +20 / +15 / ×1,13 / 35% / 15%; początek ×1,06."
	)
	for _, kind in { "full", "start" } do
		local luck = B.fortuneLuck(kind :: any)
		local cells: { { any } } = {}
		for _, field in { "monsterItem", "elite2", "gold", "bossLegendary", "bossUpgrade", "bossExtra" } do
			table.insert(cells, { luck[field] or 0, "1" })
		end
		tb.row(if kind == "full" then "pełna" else "początek (rzędy 1–2)", cells)
	end
	for _, c in B.CLASSES do
		tb.section(
			`D5: drop na godzinę, {CLASS_PL[c]}`,
			{
				"poziom · profil",
				"Unikaty / h expienia",
				"Unikaty z Fortuną",
				"Fortuna / bez (Unikaty)",
				"Heroiki / h Elit",
				"Heroiki z Fortuną",
				"Legendy / Elita II",
				"Legendy / Elita II z Fortuną",
				"premia ucięta na Elitach (pkt, z Fortuną)",
				"zabicia / h",
				"Elity / h",
			},
			"Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88)."
		)
		for L = 25, 100, 5 do
			for _, profile in B.LUCK_PROFILES do
				local d0 = B.dropsPerHour(c, L, profile.id, false)
				local d1 = B.dropsPerHour(c, L, profile.id, "full")
				local k0 = profile.id == "K0"
				local k1 = profile.id == "K1"
				tb.row(`{L} · {profile.id}`, {
					{ d0.unique, "2", if k0 then 2 else nil, if k0 then 4 else nil },
					{ d1.unique, "2" },
					{ d1.unique / math.max(1e-9, d0.unique), "2", if k1 then 1.2 else nil, if k1 then 1.35 else nil },
					{ d0.heroic, "2", if k0 then 0.5 else nil, if k0 then 1.5 else nil },
					{ d1.heroic, "2" },
					{ d0.legendaryPerElite2, "2" },
					{ d1.legendaryPerElite2, "2" },
					{ d1.eliteCut, "1" },
					{ d0.killsPerHour, "1" },
					{ d0.elitesPerHour, "1" },
				})
			end
		end
	end
	tb.section(
		"Boss z Fortuną: przedmioty dla klasy na dzień",
		{
			"boss · klasa · Fortuna",
			"Legendy",
			"Mityki",
			"Heroiki",
			"drugi przedmiot (Heroik)",
			"Legendy na tydzień",
		},
		"`Config.Boss.dailyRuns` zabić dziennie, `Loot.bossChances` z `Luck.boss` (szczęście z przedmiotów na bossy nie działa, ROZWOJ 6.2, więc profile K nie zmieniają wyniku); Legenda dla klasy z `legendaryClassShare`, Mityk z nazwanych (`mythicNamedShare`) albo losowany dla klasy."
	)
	for _, def in Bosses.list do
		for _, c in B.CLASSES do
			for _, fortune in { "bez", "początek", "pełna" } do
				local kind: any = if fortune == "pełna" then "full" elseif fortune == "początek" then "start" else nil
				local d = B.bossDrops(c, def.id, kind)
				tb.row(`{def.id} · {CLASS_PL[c]} · {fortune}`, {
					{ d.legendary, "2" },
					{ d.mythic, "2" },
					{ d.heroic, "2" },
					{ d.extra, "2" },
					{ d.legendary * 7, "2" },
				})
			end
		end
	end
	tb.section(
		"Luki poziomu przedmiotów",
		{
			"poziom",
			"zwykły potwór",
			"Elita: spawner",
			"Elita: luka",
			"Elita II: spawner",
			"Elita II: luka",
			"boss: luka",
		},
		"Luka = poziom gracza − średni ilvl dropu (`Loot.dropBaseLevel`, `ItemRoll.dropLevelRange`). Elita i Elita II: najwyższy poziom spawnera ≤ poziom gracza we wszystkich jaskiniach do tego regionu (`Data/Spawns`); boss: poziom − poziom ostatniego bossa (Legenda i Mityk na poziomie bossa). Dla S92–S94: dziury po każdym bossie i krótkie zakresy Elit."
	)
	for r = 2, #B.BANDS do
		for _, g in B.ilvlGaps(r) do
			tb.row(tostring(g.level), {
				{ g.normal, "1" },
				{ g.eliteSpawner, "i" },
				{ g.elite, "1" },
				{ g.elite2Spawner, "i" },
				{ g.elite2, "1" },
				{ g.boss, "i" },
			})
		end
	end
	tb.section(
		"Trwałość przedmiotów (P2)",
		{ "klasa · rzadkość · ilvl", "do poziomu", "poziomów" },
		"Do którego poziomu pełny zestaw rzadkości R z ilvl X ma moc (S32) co najmniej taką jak zestaw rzadkości R − 1 z poziomu − 2 (jak `diag_longevity`)."
	)
	for _, c in { "Warrior", "Mage" } do
		for rarity = 3, 5 do
			for _, ilvl in { 20, 45, 70 } do
				local until_ = B.longevity(c, rarity, ilvl)
				tb.row(`{CLASS_PL[c]} · {RARITY_PL[rarity]} · {ilvl}`, { { until_, "i" }, { until_ - ilvl, "i" } })
			end
		end
	end
	flush()

	-- Defence ---------------------------------------------------------------------------------------------------
	tb, flush = band("S84-defence")
	local defenceColumns = { "rodzaj" }
	for _, L in B.ITEM_LEVELS do
		table.insert(defenceColumns, `pancerz {L}`)
	end
	for _, L in B.ITEM_LEVELS do
		table.insert(defenceColumns, `odporność {L}`)
	end
	table.insert(defenceColumns, "unik %")
	tb.section(
		"Udział pancerza i odporności magicznej",
		defenceColumns,
		"`Balance.armorShare` = `Damage.reduction(pancerz albo odporność potwora poziomu L, L)` dla gracza poziomu L, potwory z `MonsterStats.compute` (rodzaj zwykły z cechą obrony rodziny; bossy na swoim poziomie, kolumna ich poziomu). Cel (S88): pancerz zwykły 15–21%, opancerzony 25–33%; odporność magiczna zwykła 12–17%, `mresMul` 1,8 21–27% (raport)."
	)
	for _, entry in B.defenceKinds() do
		local cells: { { any } } = {}
		local kind = entry.kind
		-- the 25-33 % band is the `armored` trait's only (dragon `scaled` x1.4 has no band, like its resistance)
		local armoredBand = entry.defence == "armored"
		local wardedBand = (kind.mresMul or 1) >= 1.8
		for _, L in B.ITEM_LEVELS do
			local m = B.monster(kind, L)
			if armoredBand then
				table.insert(cells, { B.armorShare(m, L, false), "%", 0.25, 0.33 })
			elseif (kind.defMul or 1) == 1 then
				table.insert(cells, { B.armorShare(m, L, false), "%", 0.15, 0.21 })
			else
				table.insert(cells, { B.armorShare(m, L, false), "%" })
			end
		end
		for _, L in B.ITEM_LEVELS do
			local m = B.monster(kind, L)
			if wardedBand then
				table.insert(cells, { B.armorShare(m, L, true), "%", 0.21, 0.27 })
			elseif (kind.mresMul or 1) == 1 then
				table.insert(cells, { B.armorShare(m, L, true), "%", 0.12, 0.17 })
			else
				table.insert(cells, { B.armorShare(m, L, true), "%" })
			end
		end
		table.insert(cells, { kind.dodge or 0, "1" })
		tb.row(entry.id, cells)
	end
	for _, def in Bosses.list do
		local m = B.monster(B.bossKind(def, 1), def.level, "boss")
		local cells: { { any } } = {}
		for _, L in B.ITEM_LEVELS do
			table.insert(cells, { if L == def.level then B.armorShare(m, L, false) else 0 / 0, "%" })
		end
		for _, L in B.ITEM_LEVELS do
			table.insert(cells, { if L == def.level then B.armorShare(m, L, true) else 0 / 0, "%" })
		end
		table.insert(cells, { m.dodge or 0, "1" })
		tb.row(`boss {def.id} (L{def.level})`, cells)
	end
	for _, c in B.CLASSES do
		tb.section(
			`Walka 1 na 1 z obroną rodzin, {CLASS_PL[c]}`,
			{
				"poziom · rodzaj",
				"s",
				"HP",
				"udział obrony",
				"udział uniku",
				"s bez kompensaty",
				"HP bez kompensaty",
			},
			"Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66)."
		)
		for _, L in B.ITEM_LEVELS do
			for _, r in B.defenceAt(c, L) do
				tb.row(`{L} · {r.id}`, {
					{ r.seconds, "s" },
					{ r.hpLost, "%" },
					{ r.defenceShare, "%" },
					{ r.dodgeShare, "%" },
					{ r.secondsNoComp, "s" },
					{ r.hpLostNoComp, "%" },
				})
			end
		end
	end
	tb.section(
		"Przeciw obronie: zysk DPS",
		{ "poziom · źródło", "zwykły", "opancerzony / odporny" },
		"Zysk obrażeń przy stałym niszczeniu albo przebiciu (`Damage.reduction`): Niszczenie pancerza na pełnych stosach (`Traits.armorBreakCap`), Bełt przeciwpancerny (limit `pierce` z `Data/Stats`), linie `pierce` / `magicPierce` ze środka rzutu Legendarnego; opancerzony = nieumarły `armored`, odporny = nieumarły `warded`. STATY 7: niszczenie 50% na opancerzonym ok. +17%, przebicie 20% ok. +6%."
	)
	for _, L in B.ITEM_LEVELS do
		for _, r in B.vsDefence(L) do
			tb.row(`{L} · {r.label}`, { { r.generic, "%" }, { r.defended, "%" } })
		end
	end
	flush()
	return out
end

-- Items fixture (S84 K1) ------------------------------------------------------------------------------------------

BalanceTables.ITEMS_FIXTURE_PATH = "tests/fixtures/balance_items.json"
-- Modules the S84 model reads (dataHash): a change in any of them may change the tables (S87 and later).
BalanceTables.ITEM_MODEL_MODULES = {
	"ItemTraits",
	"Families",
	"Luck",
	"Recipes",
	"LootTables",
	"Rarities",
	"Bonuses",
	"Combat",
	"BuffCategories",
	"Stats",
	"Items/Bases",
	"Blessings",
	"GuildSkills",
	"Shops",
	"Paths/Cleric",
	"Monsters",
	"Bosses",
	"Areas/Caves",
	"AreaProfiles",
	"QuestBudget", -- S98: the monster EXP multiplier moves the kills of a level (Balance.levelIncome)
	"Quests/Boss", -- S98: the boss quests pay EXP and gold in the band (Balance.levelIncome)
	"Quests/Contracts", -- S99: the hunting contracts pay EXP and gold in the band (Balance.levelIncome)
	"Config",
}

-- FNV-1a 32 bit of a text (exact in doubles: the product is split into a shift and a small multiple).
function BalanceTables.fnv1a(text: string): number
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (bit32.lshift(hash, 24) + hash * 403) % 4294967296
	end
	return hash
end

-- dataHash of the items fixture: per module, FNV-1a of the sorted "key=%.10g" lines of its Balance.dataDump part
-- (the entries of tools/balance_reasons.luau, Config with its CONFIG_KEYS and Boss).
function BalanceTables.itemDataHash(): { [string]: string }
	local Reasons = (require :: any)("../tools/balance_reasons")
	local entries = {}
	for _, name in BalanceTables.ITEM_MODEL_MODULES do
		if name ~= "Config" then
			local path = `Data/{name}`
			local found: any = { path = path }
			for _, entry in Reasons.BALANCE_MODULES do
				if entry.path == path then
					found = entry
				end
			end
			table.insert(entries, found)
		end
	end
	local config = table.clone(Reasons.CONFIG_KEYS)
	table.insert(config, "Boss")
	local skipped = B.skippedFunctions
	local dump = B.dataDump({ BALANCE_MODULES = entries, CONFIG_KEYS = config, NOT_BALANCE = {}, reasons = {} })
	B.skippedFunctions = skipped
	local lines: { [string]: { string } } = {}
	for key, v in dump do
		local module = string.match(key, "^([^:]+):") :: string
		lines[module] = lines[module] or {}
		table.insert(lines[module], `{key}={string.format("%.10g", v)}`)
	end
	local out: { [string]: string } = {}
	for _, name in BalanceTables.ITEM_MODEL_MODULES do
		local list = lines[name] or {}
		table.sort(list)
		out[name] = string.format("%08x", BalanceTables.fnv1a(table.concat(list, "\n")))
	end
	return out
end

export type ItemsFixtureReport = {
	found: boolean,
	sameData: boolean, -- every dataHash equal to the fixture's
	changedModules: { string },
	count: number,
	diffs: { FixtureDiff }, -- relative difference above the tolerance, biggest first
	missing: { string },
	added: { string },
}

function BalanceTables.readItemsFixture(): any?
	if not fs.isFile(BalanceTables.ITEMS_FIXTURE_PATH) then
		return nil
	end
	return serde.decode("json", fs.readFile(BalanceTables.ITEMS_FIXTURE_PATH))
end

-- The S84 tables against tests/fixtures/balance_items.json.
function BalanceTables.itemsFixtureDiff(now: { [string]: number }?, tolerance: number?): ItemsFixtureReport
	local file = BalanceTables.readItemsFixture()
	local before: { [string]: number } = if file then file.values or {} else {}
	local values = now or BalanceTables.values(BalanceTables.tablesItems())
	local tol = tolerance
		or (if file and file.meta then file.meta.tolerance else nil)
		or BalanceTables.FIXTURE_TOLERANCE
	local hash = BalanceTables.itemDataHash()
	local changed: { string } = {}
	for _, name in BalanceTables.ITEM_MODEL_MODULES do
		if not file or not file.dataHash or file.dataHash[name] ~= hash[name] then
			table.insert(changed, name)
		end
	end
	local diffs: { FixtureDiff } = {}
	local missing: { string } = {}
	local added: { string } = {}
	local count = 0
	for key, b in before do
		count += 1
		local a = values[key]
		if a == nil then
			table.insert(missing, key)
		else
			local rel = BalanceTables.relative(a, b)
			if rel > tol then
				table.insert(diffs, { key = key, before = b, after = a, rel = rel, allowed = false })
			end
		end
	end
	for key in values do
		if before[key] == nil then
			table.insert(added, key)
		end
	end
	table.sort(diffs, function(x, y)
		if x.rel ~= y.rel then
			return x.rel > y.rel
		end
		return x.key < y.key
	end)
	table.sort(missing)
	table.sort(added)
	return {
		found = file ~= nil,
		sameData = file ~= nil and #changed == 0,
		changedModules = changed,
		count = count,
		diffs = diffs,
		missing = missing,
		added = added,
	}
end

return BalanceTables
