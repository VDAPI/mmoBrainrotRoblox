--!strict
-- Balance report (S32): `lune run tools/balance_report.luau` writes docs/BALANS.md from the model in
-- tests/Balance.luau (the game's own modules). `lune run tools/balance_report.luau snapshot` stores the current
-- numbers in tools/balance_before.json; the report shows "before → after" wherever a number changed.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local B = require("../tests/Balance")
local Bosses = require("../src/shared/Data/Bosses")
local Combat = require("../src/shared/Data/Combat")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local ItemValue = require("../src/shared/Logic/ItemValue")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Monsters = require("../src/shared/Data/Monsters")
local Rarities = require("../src/shared/Data/Rarities")

local SNAPSHOT = "tools/balance_before.json"
local OUT = "docs/BALANS.md"
local LEVELS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }
local KEY_LEVELS = { 1, 2, 5, 10, 15, 18, 20 }

type Cell = { key: string, value: number, fmt: string }
type Table = { title: string, note: string?, columns: { string }, rows: { { label: string, cells: { Cell } } } }

local tables: { Table } = {}
local current: Table
local values: { [string]: number } = {}

local function section(title: string, columns: { string }, note: string?)
	current = { title = title, note = note, columns = columns, rows = {} }
	table.insert(tables, current)
end

-- fmt: "i" integer, "1" one decimal, "2" two decimals, "%" percent, "s" seconds (one decimal)
local function row(label: string, cells: { { any } })
	local out = {}
	for i, c in cells do
		local key = `{current.title}|{label}|{current.columns[i + 1] or i}`
		local value = c[1] :: number
		values[key] = value
		table.insert(out, { key = key, value = value, fmt = c[2] or "i" })
	end
	table.insert(current.rows, { label = label, cells = out })
end

local function fmtValue(value: number, fmt: string): string
	if value ~= value then
		return "–"
	end
	local text
	if fmt == "%" then
		text = string.format("%d%%", math.floor(value * 100 + 0.5))
	elseif fmt == "1" or fmt == "s" then
		text = string.format("%.1f", value)
	elseif fmt == "2" then
		text = string.format("%.2f", value)
	else
		local n = math.floor(value + 0.5)
		text = tostring(n)
		if math.abs(n) >= 10000 then
			text = string.gsub(string.reverse(string.gsub(string.reverse(tostring(n)), "(%d%d%d)", "%1 ")), "^ ", "")
		end
	end
	return (string.gsub(text, "%.", ","))
end

-- Model ------------------------------------------------------------------------------------------------------

local function kindDef(id: string): any
	return Monsters.get(id)
end

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

section("Zwykły potwór (mnożniki rodzaju 1)", { "poziom", "HP", "atak", "pancerz", "EXP", "złoto", "EXP do poziomu" })
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
for _, id in {
	"potion_hp_1",
	"potion_hp_2",
	"potion_hp_3",
	"backpack_30",
	"backpack_45",
	"backpack_60",
	"stone_return",
	"scroll_protection",
} do
	local def = Items.get(id) :: any
	if def then
		local item = { uid = "x", id = id, rarity = def.rarity or 1, ilvl = def.level, bonuses = {}, up = 0, bound = false, n = 1 }
		row(id, { { def.buyPrice or 0, "i" }, { ItemValue.value(item :: any), "i" } })
	end
end
for _, L in { 5, 10, 15, 20 } do
	local def = Items.get(`sword1h_{Items.generate.tierFor(L)}`) :: any
	row(`miecz ilvl {L}`, { { ItemValue.equipment(def, L, 1, 0) * ItemValue.BUY_MUL, "i" }, { ItemValue.equipment(def, L, 1, 0), "i" } })
end

-- Output -------------------------------------------------------------------------------------------------------

local mode = process.args[1]
if mode == "snapshot" then
	fs.writeFile(SNAPSHOT, serde.encode("json", values, true))
	print(`wrote {SNAPSHOT} ({#tables} tables)`)
	return
end

local before: { [string]: number } = {}
if fs.isFile(SNAPSHOT) then
	before = serde.decode("json", fs.readFile(SNAPSHOT))
end

local lines = {
	"# Vaelthorn: balans poziomów 1–20",
	"",
	"> Plik generowany: `lune run tools/balance_report.luau` (model `tests/Balance.luau`, moduły gry).",
	"> „a → b” = przed S32 → teraz (migawka `tools/balance_before.json`). Nie edytuj ręcznie.",
	"",
	"Założenia: ekwipunek „na poziomie” = broń + druga ręka + 4 części zbroi + naszyjnik + 2 pierścienie + talizman,",
	"Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; wszystkie punkty w główną statystykę; zwykłe ataki + 1–2 umiejętności",
	"(×1,2 obrażeń), bez mikstur; potwór uderza od razu, potem co swój interwał; regeneracja w walce 0,1%/s.",
	`Stałe walki: redukcja = def / (def + {Combat.reductionPerLevel}·poziom atakującego + {Combat.reductionBase}).`,
	"",
}

for _, t in tables do
	table.insert(lines, `## {t.title}`)
	table.insert(lines, "")
	if t.note then
		table.insert(lines, t.note)
		table.insert(lines, "")
	end
	table.insert(lines, "| " .. table.concat(t.columns, " | ") .. " |")
	local sep = {}
	for i = 1, #t.columns do
		sep[i] = if i == 1 then "---" else "--:"
	end
	table.insert(lines, "| " .. table.concat(sep, " | ") .. " |")
	for _, r in t.rows do
		local cells = { r.label }
		for _, c in r.cells do
			local now = fmtValue(c.value, c.fmt)
			local old = before[c.key]
			local text = now
			if old ~= nil and fmtValue(old, c.fmt) ~= now then
				text = `{fmtValue(old, c.fmt)} → {now}`
			end
			table.insert(cells, text)
		end
		table.insert(lines, "| " .. table.concat(cells, " | ") .. " |")
	end
	table.insert(lines, "")
end

-- Monster kinds and bosses used above, for reference.
table.insert(lines, "## Wzory (stan obecny)")
table.insert(lines, "")
table.insert(
	lines,
	`- Potwór: HP = {Combat.monsterHpBase} + {Combat.monsterHpFactor}·L^{Combat.monsterHpExponent}, atak = {Combat.monsterAtkBase} + {Combat.monsterAtkFactor}·L^{Combat.monsterAtkExponent}, pancerz {Combat.monsterArmorPerLevel}·L, atak co {Combat.monsterAttackInterval} s / szybkość.`
)
local groupMul = (Combat :: any).groupDamageMul
if groupMul then
	table.insert(lines, `- Obrażenia członka grupy wg rozmiaru 1–4: {table.concat(groupMul, " / ")}.`)
end
for _, variant in { "normal", "elite", "elite2", "boss" } do
	local v = Combat.variants[variant]
	table.insert(lines, `- Wariant {variant}: +{v.levelAdd} poz., HP ×{v.hpMul}, obrażenia ×{v.dmgMul}.`)
end
local grimrok = Bosses.byId.grimrok :: any
local attacks = {}
for _, a in grimrok.attacks do
	table.insert(attacks, `{a.id} ×{a.damage}`)
end
table.insert(lines, `- Grimrok: atak ×{grimrok.atkMul}, ciosy {table.concat(attacks, ", ")}.`)
local stats: any = MonsterStats
if stats.kindReward then
	table.insert(
		lines,
		`- EXP i złoto rodzaju × mnożnik HP^{(Combat :: any).kindRewardHpExponent} × (mnożnik ataku × szybkość)^{(Combat :: any).kindRewardAtkExponent}.`
	)
end
table.insert(lines, "")

fs.writeFile(OUT, table.concat(lines, "\n"))
print(`wrote {OUT}`)
