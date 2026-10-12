--!strict
-- Balance report 1-100 (S32, S83): `lune run tools/balance_report.luau` writes docs/BALANS.md from the model in
-- tests/Balance.luau and the tables in tests/BalanceTables.luau (the game's own modules).
--   snapshot [S<n>]  stores tools/balance_before.json = { meta, tables, data }: every report number ("before" of the
--                    next report) and the ledger dump (Balance.dataDump + rankDump). Without S<n>: the last
--                    "### S<n>" of docs/SESJE.md + 1. Balance sessions S83-S94 start with it.
--   fixture [S<n> [note]]  writes tests/fixtures/balance_1_20.json (the 1-20 reference of tests/balance1_20.spec);
--                    the session as for snapshot, the note optional.
--   --fixture-items [note]  (S84, also without "--") writes tests/fixtures/balance_items.json = { meta, values,
--                    dataHash } of BalanceTables.tablesItems() (tests/balance.spec "Balance 20-100: items, loot,
--                    defence (S84)"); no commit or date in it, so a second run gives the same bytes.
-- The report starts with the ledger ("Zmiany danych"): a changed number of tools/balance_reasons.luau's modules
-- without a reason marks the row and exits 1 after writing the file (like balance.spec).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local B = require("../tests/Balance")
local BalanceTables = require("../tests/BalanceTables")
local Bosses = require("../src/shared/Data/Bosses")
local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local LevelCurves = require("../src/shared/Logic/LevelCurves")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Progression = require("../src/shared/Data/Progression")
local Reasons = require("./balance_reasons")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")

local SNAPSHOT = "tools/balance_before.json"
local OUT = "docs/BALANS.md"
local started = os.clock()

local function gitCommit(): string
	local ok, result = pcall(process.exec, "git", { "rev-parse", "--short", "HEAD" })
	if ok and result.ok then
		return (string.gsub(result.stdout, "%s+$", ""))
	end
	return "unknown"
end

-- The session a snapshot without an argument belongs to: the last "### S<n>" of docs/SESJE.md + 1.
local function nextSession(): string
	local last = 0
	if fs.isFile("docs/SESJE.md") then
		for n in string.gmatch(fs.readFile("docs/SESJE.md"), "\n### S(%d+)") do
			last = math.max(last, tonumber(n) or 0)
		end
	end
	return `S{last + 1}`
end

local mode = process.args[1]

if mode == "fixture" then
	local session = process.args[2]
	if session == nil or not B.sessionNumber(session) then
		session = nextSession()
		print(`fixture: session {session} (last ### S<n> in docs/SESJE.md + 1)`)
	end
	local file = {
		meta = {
			session = session,
			commit = gitCommit(),
			tolerance = BalanceTables.FIXTURE_TOLERANCE,
			note = process.args[3],
		},
		values = BalanceTables.values(BalanceTables.tables1_20(), true),
	}
	fs.writeFile(BalanceTables.FIXTURE_PATH, serde.encode("json", file, true))
	print(`wrote {BalanceTables.FIXTURE_PATH}`)
	return
end

if mode == "--fixture-items" or mode == "fixture-items" then
	local file = {
		meta = {
			session = "S84",
			tolerance = BalanceTables.FIXTURE_TOLERANCE,
			note = process.args[2]
				or "S84: model przedmiotów, łupu i obrony potworów 20–100 (tests/BalanceTables.tablesItems)",
		},
		values = BalanceTables.values(BalanceTables.tablesItems()),
		dataHash = BalanceTables.itemDataHash(),
	}
	fs.writeFile(BalanceTables.ITEMS_FIXTURE_PATH, serde.encode("json", file, true))
	print(`wrote {BalanceTables.ITEMS_FIXTURE_PATH}`)
	return
end

local tables = BalanceTables.tablesAll()
local data = B.ledgerData(Reasons :: any)

if mode == "snapshot" then
	local session = process.args[2]
	if session == nil or not B.sessionNumber(session) then
		session = nextSession()
		print(`snapshot: session {session} (last ### S<n> in docs/SESJE.md + 1)`)
	end
	local file = {
		meta = { session = session, commit = gitCommit(), date = os.date("!%Y-%m-%d") },
		tables = BalanceTables.values(tables),
		data = data,
	}
	local text = serde.encode("json", file, true)
	fs.writeFile(SNAPSHOT, text)
	print(`wrote {SNAPSHOT} ({#tables} tables, {string.format("%.2f", #text / 1048576)} MB)`)
	return
end

-- Snapshot -----------------------------------------------------------------------------------------------------

local beforeTables: { [string]: number } = {}
local beforeData: { [string]: number }? = nil
local meta: any = nil
if fs.isFile(SNAPSHOT) then
	local decoded = serde.decode("json", fs.readFile(SNAPSHOT))
	if type(decoded.meta) == "table" then
		meta = decoded.meta
		beforeTables = decoded.tables or {}
		beforeData = decoded.data
	else
		beforeTables = decoded -- the flat format before S83: tables only, no ledger
	end
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
	elseif fmt == "g" then
		text = string.format("%.4g", value)
	else
		local n = math.floor(value + 0.5)
		text = tostring(n)
		if math.abs(n) >= 10000 then
			text = string.gsub(string.reverse(string.gsub(string.reverse(tostring(n)), "(%d%d%d)", "%1 ")), "^ ", "")
		end
	end
	return (string.gsub(text, "%.", ","))
end

local lines: { string } = {}
local function add(line: string?)
	table.insert(lines, line or "")
end

local function tableOut(columns: { string }, rows: { { string } })
	add("| " .. table.concat(columns, " | ") .. " |")
	local sep = {}
	for i = 1, #columns do
		sep[i] = if i == 1 then "---" else "--:"
	end
	add("| " .. table.concat(sep, " | ") .. " |")
	for _, r in rows do
		add("| " .. table.concat(r, " | ") .. " |")
	end
	add()
end

local function renderTable(t: BalanceTables.Table, level: string)
	add(`{level} {t.title}`)
	add()
	if t.note then
		add(t.note)
		add()
	end
	local rows = {}
	for _, r in t.rows do
		local cells = { r.label }
		for _, c in r.cells do
			local now = fmtValue(c.value, c.fmt)
			local old = beforeTables[c.key]
			local text = now
			if old ~= nil and fmtValue(old, c.fmt) ~= now then
				text = `{fmtValue(old, c.fmt)} → {now}`
			end
			-- S84: a value outside the cell's band in bold
			local v = c.value
			if v == v and ((c.low ~= nil and v < c.low) or (c.high ~= nil and v > c.high)) then
				text = `**{text}**`
			end
			table.insert(cells, text)
		end
		table.insert(rows, cells)
	end
	tableOut(t.columns, rows)
end

local function bandOfRank(skill: any, r: number): string
	local L = Skills.rankLevel(skill, r)
	return if L <= 20 then "≤ 20" elseif L <= 45 then "21–45" elseif L <= 70 then "46–70" else "71–100"
end

-- Header --------------------------------------------------------------------------------------------------------

add("# Vaelthorn: balans poziomów 1–100")
add()
add("> Plik generowany: `lune run tools/balance_report.luau` (model `tests/Balance.luau`, tabele")
add("> `tests/BalanceTables.luau`, moduły gry). Nie edytuj ręcznie.")
if meta then
	add(`> „a → b” = migawka {meta.session} (commit {meta.commit}, {meta.date}) → teraz (\`{SNAPSHOT}\`).`)
else
	add(`> „a → b” = stara migawka w płaskim formacie (sprzed S83, bez księgi) → teraz.`)
end
add("> Tryby: `lune run tools/balance_report.luau snapshot [S<n>]` (nowa migawka „przed”: tabele i zrzut danych")
add(
	"> księgi), `lune run tools/balance_report.luau fixture [S<n>]` (fixture 1–20 dla `tests/balance1_20.spec.luau`)."
)
add()
add(
	"Założenia: ekwipunek „na poziomie” = broń + druga ręka + 4 części zbroi + naszyjnik + 2 pierścienie + talizman,"
)
add(
	"Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; wszystkie punkty w główną statystykę; zwykłe ataki + 1–2 umiejętności"
)
add("(×1,2 obrażeń); potwór uderza od razu, potem co swój interwał; regeneracja w walce 0,1%/s.")
add(`Stałe walki: redukcja = def / (def + {Combat.reductionPerLevel}·poziom atakującego + {Combat.reductionBase}).`)
add()

-- Ledger --------------------------------------------------------------------------------------------------------

local unexplained: { string } = {}
add("## Zmiany danych (księga, `tools/balance_reasons.luau`)")
add()
if beforeData == nil then
	add("Migawka bez zrzutu danych (płaski format sprzed S83): księga pominięta.")
	add()
else
	local result = B.ledger(beforeData :: any, data, Reasons.reasons, meta.session)
	unexplained = result.unexplained
	local function reasonCells(line: B.LedgerLine): (string, string)
		if line.reason then
			return line.reason.session, line.reason.why
		end
		return "–", "**BRAK POWODU**"
	end
	local function num(v: number?): string
		return if v == nil then "–" else fmtValue(v, "g")
	end
	local changed, ranks = {}, {}
	for _, line in result.changed do
		local skillId, field, r = string.match(line.key, "^Rangi:([^%.]+)%.([^@]+)@(%d+)$")
		if skillId then
			local skill = SkillData.byId[skillId]
			local band = if skill then bandOfRank(skill, tonumber(r) :: number) else "?"
			local warn = if band == "≤ 20" then " **UWAGA: pasmo 1–20**" else ""
			table.insert(ranks, { `{skillId}.{field}`, r :: string, band .. warn, num(line.before), num(line.after) })
		else
			local session, why = reasonCells(line)
			table.insert(changed, { `\`{line.key}\``, num(line.before), num(line.after), session, why })
		end
	end
	if #changed == 0 and #result.added == 0 and #result.removed == 0 and #ranks == 0 then
		add(`Brak zmian liczb balansu od migawki {meta.session}.`)
		add()
	else
		if #changed > 0 then
			tableOut({ "klucz", "przed", "po", "sesja", "powód" }, changed)
		end
		for _, part in { { "Nowe klucze", result.added }, { "Usunięte klucze", result.removed } } do
			local list = part[2] :: { B.LedgerLine }
			local rows = {}
			for _, line in list do
				if string.sub(line.key, 1, 6) ~= "Rangi:" then
					local session, why = reasonCells(line)
					table.insert(rows, { `\`{line.key}\``, num(line.before or line.after), session, why })
				end
			end
			if #rows > 0 then
				add(`### {part[1]}`)
				add()
				tableOut({ "klucz", "wartość", "sesja", "powód" }, rows)
			end
		end
		if #ranks > 0 then
			add("### Rangi (liczby pochodne, bez osobnego powodu)")
			add()
			tableOut({ "umiejętność.pole", "ranga", "pasmo rangi", "przed", "po" }, ranks)
		end
	end
end
if #B.skippedFunctions > 0 then
	add("### Księga: pominięte funkcje")
	add()
	add(
		"Funkcje modułów księgi, które dla poziomów 1, 20, 45, 70, 100 nie zwracają liczby ani tabeli (np. `get(id)`):"
	)
	add(`{table.concat(B.skippedFunctions, ", ")}.`)
	add()
end

-- Rank bands ----------------------------------------------------------------------------------------------------

add("## Własność pasm umiejętności")
add()
add(
	"Ranga należy do pasma swojego poziomu `Skills.rankLevel` (≤ 20 → strojenie 1–20 w S91; 21–45, 46–70, 71–100 →"
)
add(
	"sesje regionów). Sesja zmienia wartość tylko na rangach swojego pasma (rangę 1 przy odblokowaniu w paśmie, rangę"
)
add("maks. gdy osiągana jest w paśmie, resztę węzłem `Data/SkillCurves`).")
add()
for _, classId in B.CLASSES do
	local list = {}
	for _, skill in SkillData.byClass[classId] do
		table.insert(list, skill)
	end
	table.sort(list, function(a, b)
		if a.unlock ~= b.unlock then
			return a.unlock < b.unlock
		end
		return a.id < b.id
	end)
	local rows = {}
	for _, skill in list do
		local levels, last20 = {}, "–"
		local inBand: { [string]: { string } } = { ["21–45"] = {}, ["46–70"] = {}, ["71–100"] = {} }
		for r = 1, skill.maxLevel do
			local L = Skills.rankLevel(skill, r)
			table.insert(levels, tostring(L))
			local band = bandOfRank(skill, r)
			if band == "≤ 20" then
				last20 = tostring(r)
			else
				table.insert(inBand[band], tostring(r))
			end
		end
		local function joined(t: { string }): string
			return if #t > 0 then table.concat(t, ", ") else "–"
		end
		table.insert(rows, {
			`{skill.id}{if skill.path then ` ({skill.path})` else ""}`,
			tostring(skill.unlock),
			table.concat(levels, " / "),
			last20,
			joined(inBand["21–45"]),
			joined(inBand["46–70"]),
			joined(inBand["71–100"]),
		})
	end
	add(`### {BalanceTables.CLASS_PL[classId]}`)
	add()
	tableOut({ "umiejętność", "odblok.", "poziomy rang", "ostatnia ≤ 20", "21–45", "46–70", "71–100" }, rows)
end

-- Targets -------------------------------------------------------------------------------------------------------

local function bound(v: number?): string
	return if v == nil then "" else fmtValue(v, "2")
end

local function targetRows(rows: { B.TargetRow }, who: string): { { string } }
	local out = {}
	for _, row in rows do
		local band = if row.low and row.high
			then `{bound(row.low)}–{bound(row.high)}`
			elseif row.low then `≥ {bound(row.low)}`
			else `≤ {bound(row.high)}`
		table.insert(out, {
			row.label,
			fmtValue(row.value, "2"),
			band,
			if B.inBand(row) then "w paśmie" else "**poza**",
			row.report or who,
		})
	end
	return out
end

local function countIn(rows: { B.TargetRow }): (number, number)
	local ok = 0
	for _, row in rows do
		ok += if B.inBand(row) then 1 else 0
	end
	return ok, #rows
end

local globalRows = B.targetsGlobal()
-- Global rows of a band: G1-G6 by level (lo <= L < hi, 100 in the last band), G11 by the boss level, G13 in 20-45
-- (the band sums in their own band), G12 in 1-20.
local function globalFor(lo: number, hi: number): { B.TargetRow }
	local out = {}
	for _, row in globalRows do
		local L = row.level
		local inside
		if row.group == "G7" or row.group == "G8" or row.group == "G9" then
			inside = false -- S84: in the item sections
		elseif row.id == "G13.band" then
			inside = L == lo
		elseif row.group == "G13" then
			inside = lo == 20
		elseif row.group == "G12" then
			inside = lo == 1
		else
			inside = L ~= nil and L >= lo and (L < hi or (hi == 100 and L == 100))
		end
		if inside then
			table.insert(out, row)
		end
	end
	return out
end

-- Bands ---------------------------------------------------------------------------------------------------------

local byBand: { [string]: { BalanceTables.Table } } = {}
for _, t in tables do
	byBand[t.band] = byBand[t.band] or {}
	table.insert(byBand[t.band], t)
end

local REGION_SESSION = { "S91", "S92", "S93", "S94" }
for i, band in B.BANDS do
	local lo, hi = band[1], band[2]
	local mapId = B.REGION_IDS[i]
	local tuned = B.TUNED[mapId]
	local untuned = if tuned then "" else ": raport, nie strojone"
	add(`## Pasmo {lo}–{hi} ({mapId}){untuned}`)
	add()
	for _, t in byBand[`{lo}-{hi}`] or {} do
		renderTable(t, "###")
	end
	if lo == 1 then
		local s32 = B.targets1_20()
		local ok, all = countIn(s32)
		add("### Cele 1–20 (S32, raport do S91)")
		add()
		add(`{ok}/{all} w paśmie. Bloki S32 w \`balance.spec\` są do S91 raportem (odpowiedź właściciela 4).`)
		add()
		tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(s32, "S91"))
		local fixture = BalanceTables.fixtureDiff()
		local tolerance = fmtValue(BalanceTables.FIXTURE_TOLERANCE * 100, "1")
		add(
			`G12 (fixture 1–20): {#fixture.diffs} różnic powyżej {tolerance}%, {#fixture.missing} brakujących kluczy `
				.. "(`tests/balance1_20.spec.luau`, asertuje S91)."
		)
		add()
	end
	local gRows = globalFor(lo, hi)
	local regionRows = B.targetsRegion(mapId)
	local cele = targetRows(gRows, "S87")
	local regionWho = if tuned then "S83 (rodzaje, harmonogram) / S91" else REGION_SESSION[i]
	for _, r in targetRows(regionRows, regionWho) do
		table.insert(cele, r)
	end
	local gOk, gAll = countIn(gRows)
	local rOk, rAll = countIn(regionRows)
	add(`### Cele ({lo}–{hi}){untuned}`)
	add()
	add(`Globalne (G): {gOk}/{gAll} w paśmie; regionu: {rOk}/{rAll} w paśmie.`)
	add()
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, cele)
end

-- Items, loot and monster defence (S84) -------------------------------------------------------------------------

do
	local items: { B.TargetRow } = {}
	for _, row in globalRows do
		if row.group == "G7" or row.group == "G8" or row.group == "G9" then
			table.insert(items, row)
		end
	end
	for _, section in BalanceTables.ITEM_BANDS do
		add(`## {section.title}`)
		add()
		add(section.intro)
		add()
		for _, t in byBand[section.band] or {} do
			renderTable(t, "###")
		end
		if section.band == "S84-upgrades" then
			local ok, all = countIn(items)
			local out = {}
			for _, row in items do
				if not B.inBand(row) then
					table.insert(out, row)
				end
			end
			add("### Cele G7–G9 (S84, raport do S87)")
			add()
			add(
				`{ok}/{all} w paśmie (G7: kolumna „z cechami”, G8: MIX „bez cech” i „z cechami”, G9: +1…+3 / dochód i +1…+9 z ochroną). Poza pasmem:`
			)
			add()
			tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(out, "S87"))
		end
	end
end

-- Formulas ------------------------------------------------------------------------------------------------------

add("## Wzory (stan obecny)")
add()
add(
	`- Potwór: HP = {Combat.monsterHpBase} + {Combat.monsterHpComp}·{Combat.monsterHpFactor}·L^{Combat.monsterHpExponent}, atak = {Combat.monsterAtkBase} + {Combat.monsterAtkFactor}·L^{Combat.monsterAtkExponent}, pancerz {Combat.monsterArmorPerLevel}·L × defMul, odporność magiczna {Combat.monsterMresPerLevel}·L × mresMul, atak co {Combat.monsterAttackInterval} s / szybkość.`
)
local groupMul = (Combat :: any).groupDamageMul
if groupMul then
	add(`- Obrażenia członka grupy wg rozmiaru 1–4: {table.concat(groupMul, " / ")}.`)
end
for _, variant in { "normal", "elite", "elite2", "boss" } do
	local v = Combat.variants[variant]
	add(`- Wariant {variant}: +{v.levelAdd} poz., HP ×{v.hpMul}, obrażenia ×{v.dmgMul}.`)
end
for _, def in Bosses.list do
	local attacks = {}
	for _, a in def.attacks do
		table.insert(attacks, `{a.id} ×{a.damage}`)
	end
	add(`- {def.id} (L{def.level}): atak ×{def.atkMul}, ciosy {table.concat(attacks, ", ")}.`)
end
local stats: any = MonsterStats
if stats.kindReward then
	local hpExp, atkExp = (Combat :: any).kindRewardHpExponent, (Combat :: any).kindRewardAtkExponent
	add(`- EXP i złoto rodzaju × mnożnik HP^{hpExp} × (mnożnik ataku × szybkość)^{atkExp}.`)
end
local curve = {}
for _, L in { 20, 45, 70, 100 } do
	table.insert(curve, `{L}: {fmtValue(Config.PotionCooldown * LevelCurves.at("potionCooldown", L), "1")} s`)
end
add(
	`- Mikstury (S54): odstęp \`Potions.interval\` = {Config.PotionCooldown} s × krzywa \`potionCooldown\` ({table.concat(
		curve,
		", "
	)}).`
)
add(
	"  Model łańcuchowy: regeneracja poza walką w przerwie, potem najtańsza dozwolona jakość (`level` ≤ poziom), której"
)
add(
	"  łyki mieszczą się w przerwie (pierwszy od razu), inaczej największa z czekaniem (łyki − mieszczące) × odstęp."
)
add(
	"- Zadania 1–100 (S83): na swoim poziomie (główne + połowa pobocznych; bossowie w polu `boss`, w tempie tylko z"
)
add(
	"  `bosses`), bez rozkładania na pasmo; nadmiar EXP przechodzi na następny poziom. Tabele S32 1–20 zostają przy"
)
add("  rozkładaniu według potrzebnego EXP (`Balance.questRewards`).")
add(
	`- Drużyna (S83): bije osobno na tym samym łowisku i dzieli zaliczenie, bez synergii; EXP/h członka = średnia solowych × (1 + min({Progression.varietyMax}, {Progression.varietyPerClass}·(klasy − 1))/100); \`floor\` z \`PartyLoot.splitExp\` pominięty.`
)
add(
	`- Harmonogram bossa: \`Boss.Step\` co 0,05 s; gdy t ≥ nextGlobal, pierwszy gotowy atak fazy w kolejności listy; potem nextAttack = t + odnowienie, nextGlobal = t + zamach + {B.BOSS_GLOBAL_GAP} s; pierwszy atak po 4 s, pierwsze użycie każdego średnio po 5 s. Przyspieszenie fazy dzieli tylko odstęp ataku podstawowego, wściekłość mnoży wszystkie ciosy.`
)
add()

fs.writeFile(OUT, table.concat(lines, "\n"))
print(`wrote {OUT} ({#tables} tables, {string.format("%.1f", os.clock() - started)} s)`)

if #unexplained > 0 then
	print(`BRAK POWODU ({#unexplained}): dopisz wpisy do tools/balance_reasons.luau:`)
	for i = 1, math.min(50, #unexplained) do
		print(`  {unexplained[i]}`)
	end
	process.exit(1)
end
