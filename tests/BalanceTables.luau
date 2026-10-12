--!strict
-- Tables of the balance report (S83): the same code builds docs/BALANS.md (tools/balance_report.luau), the 1-20
-- fixture (tests/fixtures/balance_1_20.json) and checks it (tests/balance1_20.spec.luau), so the numbers can never
-- drift between them.
--
--   tables1_20()           the S32 report tables of levels 1-20, in report order (band "1-20")
--   tablesBand(lo, hi)     the S83 world model tables of a band 20-45 / 45-70 / 70-100 (levels lo, lo + 5, ..., hi)
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
local Spawns = require("../src/shared/Data/Spawns")

local BalanceTables = {}

export type Cell = { key: string, value: number, fmt: string }
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
				table.insert(out, { key = key, value = c[1] :: number, fmt = (c[2] or "i") :: string })
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
			row(`{c} {L}`, { { f.seconds, "s" }, { f.hpLost, "%" } })
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
		row(`{kind} {L}`, {
			{ solo.seconds, "s" },
			{ solo.hpLost, "%" },
			{ duo.seconds, "s" },
			{ duo.hpLost, "%" },
			{ trio.seconds, "s" },
			{ trio.hpLost, "%" },
		})
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
		row(tostring(L), {
			{ B.dropIlvl(L, "normal"), "1" },
			{ B.wearableShare(L), "%" },
			{ B.dropIlvl(L, "elite"), "1" },
			{ B.dropIlvl(L, "elite2"), "1" },
			{ kills, "1" },
			{ kills * B.itemsPerKill("normal", Rarities.UNIQUE), "2" },
			{ 3600 / B.eliteCadence("Warrior", L) * B.itemsPerKill("elite", Rarities.HEROIC), "2" },
		})
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

-- Every table of the report 1-100 (1-20, the Meadows' region tables, the three bands).
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
	return out
end

-- 1-20 fixture (S83) --------------------------------------------------------------------------------------------

BalanceTables.FIXTURE_PATH = "tests/fixtures/balance_1_20.json"
BalanceTables.FIXTURE_TOLERANCE = 0.005

export type FixtureDiff = { key: string, before: number, after: number, rel: number, allowed: boolean }
export type FixtureReport = {
	found: boolean,
	count: number, -- values in the fixture
	diffs: { FixtureDiff }, -- relative difference above the tolerance, biggest first
	missing: { string }, -- fixture keys gone from the tables
	added: number, -- table keys the fixture does not have
	unexpected: number, -- diffs outside `allowed`
}

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

return BalanceTables
