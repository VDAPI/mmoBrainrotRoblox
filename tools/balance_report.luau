--!strict
-- Balance report 1-100 (S32, S83): `lune run tools/balance_report.luau` writes docs/BALANS.md from the model in
-- tests/Balance.luau and the tables in tests/BalanceTables.luau (the game's own modules); S85: the skill model
-- tests/SkillModel.luau (section "Umiejętności: T-SK na buildach wzorcowych").
--   snapshot [S<n>]  stores tools/balance_before.json = { meta, tables, data }: every report number ("before" of the
--                    next report) and the ledger dump (Balance.dataDump + rankDump). Without S<n>: the last
--                    "### S<n>" of docs/SESJE.md + 1. Balance sessions S83-S94 start with it.
--   fixture [S<n> [note]]  writes tests/fixtures/balance_1_20.json (the 1-20 reference of tests/balance1_20.spec);
--                    the session as for snapshot, the note optional.
--   --fixture-items [note [S<n>]]  (S84, also without "--") writes tests/fixtures/balance_items.json = { meta, values,
--                    dataHash } of BalanceTables.tablesItems() (tests/balance.spec "Balance 20-100: items, loot,
--                    defence (S84)"); no commit or date in it, so a second run gives the same bytes.
--   --fixture-paths [note [S<n>]]  (S86, also without "--") writes tests/fixtures/balance_paths.json of
--                    BalanceTables.tablesPaths() the same way (tests/balance.spec "Balance 20-100: paths").
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
local Rarities = require("../src/shared/Data/Rarities")
local Reasons = require("./balance_reasons")
local SkillModel = require("../tests/SkillModel")
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

if mode == "--fixture-paths" or mode == "fixture-paths" then
	local file = {
		meta = {
			session = process.args[3] or "S86", -- S87: the session that regenerated it (third argument)
			tolerance = BalanceTables.FIXTURE_TOLERANCE,
			note = process.args[2]
				or "S86: mechaniki klas i cele ścieżek w modelu umiejętności (tests/BalanceTables.tablesPaths)",
		},
		values = BalanceTables.values(BalanceTables.tablesPaths()),
		dataHash = BalanceTables.pathDataHash(),
	}
	fs.writeFile(BalanceTables.PATHS_FIXTURE_PATH, serde.encode("json", file, true))
	print(`wrote {BalanceTables.PATHS_FIXTURE_PATH}`)
	return
end

if mode == "--fixture-items" or mode == "fixture-items" then
	local file = {
		meta = {
			session = process.args[3] or "S84", -- S87: the session that regenerated it (third argument)
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
			-- the snapshot's JSON round trip moves a float in its last digit (11.024999999999999 -> 11.025)
			if old ~= nil and not B.sameNumber(old, c.value) and fmtValue(old, c.fmt) ~= now then
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

-- "kto asertuje": the row's own report session, "S87 (asertowane)" or "raport → S<n>" (GLOBAL_REPORT_ONLY).
local function whoOf(row: B.TargetRow, who: string): string
	if type(row.report) == "string" then
		return row.report
	elseif row.report then
		return `{who} (raport)`
	elseif who == "S87" then
		local entry = B.reportOnlyFor(row)
		return if entry then `raport → {entry.session}` else "S87 (asertowane)"
	end
	return who
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
			-- S86: G10 rows outside S87's asserted three carry report = true; S87: GLOBAL_REPORT_ONLY names the session
			whoOf(row, who),
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
			add("### Cele G7–G9 (S84; asertowane od S87 poza `GLOBAL_REPORT_ONLY`)")
			add()
			add(
				`{ok}/{all} w paśmie (G7: kolumna „z cechami”, G8: MIX „bez cech” i „z cechami”, G9: +1…+3 / dochód i +1…+9 z ochroną). Poza pasmem:`
			)
			add()
			tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(out, "S87"))
		end
	end
end

-- Skills on the reference builds (S85) ----------------------------------------------------------------------------

do
	add("## Umiejętności: T-SK na buildach wzorcowych (S85)")
	add()
	add(
		"Silnik `tests/SkillModel.luau` rzuca prawdziwe umiejętności bazy każdej klasy (rzędy 1 wszystkich ścieżek, Mag 1–2, broń z pomiarów ROZWOJ i `base.loadout` z bronią `Balance.LOADOUT`) i każdego buildu `PathDef.reference` (klucz `<pathId>.<id>`) na poziomach 20 / 45 / 70 / 100: rangi z poziomu, przełomy A/B, węzły, rotacja z danych, koszt `Skills.cost`, normalizacja broni, mikstury. Bez umiejętności daje `FightSim.dps` (kontrola w `balance.spec`). S86 dołożyło mechaniki klas i cechy na zdarzeniu (sekcja „Klasy i ścieżki”); to raport, nic tu nie jest asertowane (model główny celów G zostaje ×1,2)."
	)
	add()
	for _, t in byBand["S85-skills"] or {} do
		renderTable(t, "###")
	end
	add("### Poza modelem (na build, poziom 100)")
	add()
	add(
		"Pozycje `unmodelled` (po S86 tylko nieznane klucze; haki bez wpływu na metryki są w `HOOKS_NONE`), wpisy rotacji pominięte z powodem (liczba rzutów w 60 s na 1 manekinie; wpis pominięty tylko w walce obszarowej: na 3 manekinach) i aktywne umiejętności buildu spoza rotacji."
	)
	add()
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			local m = SkillModel.metrics(build, 100)
			local skipped = {}
			for id, s in m.skipped do
				table.insert(skipped, `{id} ({s.reason}) ×{s.count}`)
			end
			table.sort(skipped)
			local parts = {
				if #m.unmodelled > 0 then table.concat(m.unmodelled, ", ") else "–",
				`pominięte: {if #skipped > 0 then table.concat(skipped, ", ") else "–"}`,
				`poza rotacją: {if #m.offRotation > 0 then table.concat(m.offRotation, ", ") else "–"}`,
			}
			add(`- {BalanceTables.CLASS_PL[c]} \`{build.key}\`: {table.concat(parts, "; ")}.`)
		end
	end
	add()
	local g10 = SkillModel.targetsG10()
	local ok, all = countIn(g10)
	add("### Cele G10 (T-SK4, T-SK5; asertowane od S87 poza `GLOBAL_REPORT_ONLY`)")
	add()
	add(
		`{ok}/{all} w paśmie (T-SK4 Maga od 45., T-SK5 Kapłana na tanku Wojowniku konwencji i Strażniku „Obrońcy”, co 5 poziomów; blok globalny \`balance.spec\` drukuje je razem z G). Poza pasmem:`
	)
	add()
	local out = {}
	for _, row in g10 do
		if not B.inBand(row) then
			table.insert(out, row)
		end
	end
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(out, "S87"))
	local meadows = SkillModel.targetsMeadows()
	local mOk, mAll = countIn(meadows)
	add("### Łąki na L20: T-SK3 i T-SK6")
	add()
	add(
		`{mOk}/{mAll} w paśmie; S86: blok regionów \`balance.spec\` asertuje wiersze bez \`report\`, reszta drukowana do S91.`
	)
	add()
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(meadows, "S86 (asercja)"))
	add(`Tabele S85 liczą się {fmtValue(BalanceTables.skillSeconds or 0, "1")} s (siatka, leczenie, porównania).`)
	add()
end

-- Classes and paths (S86) ------------------------------------------------------------------------------------------

do
	add("## Klasy i ścieżki (S86)")
	add()
	add(
		"Mechaniki klas S69–S81 w silniku `tests/SkillModel.luau` (leczenie i tarcze od maks. HP celu, kości i koło jako wartość oczekiwana, podpalenie, pole leczenia, Furia krok po kroku, blok, przechwyt, pułapki, sokół, celowanie, strumień, Ładunki Arkanów, kumulowanie, próg obszaru; każda z `-- mirrors`), cechy broni na zdarzeniu na ekwipunku konwencji S32 (Zwykły, ilvl = poziom − 2), walka z potworami, które oddają, metryki ścieżek i cele ROZWOJ jako wiersze `PATH_TARGETS`. To tylko raport: G10 asertuje S87, ścieżki Kapłana i Wojownika S89, Łowcy i Maga S90, L20 S91, regiony i bossy S92–S94. Fixture: `tests/fixtures/balance_paths.json` (`lune run tools/balance_report.luau --fixture-paths`)."
	)
	add()
	for _, t in byBand["S86-paths"] or {} do
		renderTable(t, "###")
	end
	add(`Tabele S86 liczą się {fmtValue(BalanceTables.pathSeconds or 0, "1")} s.`)
	add()
end

-- Global fixes (S87) ---------------------------------------------------------------------------------------------

do
	add("## Poprawki globalne (S87)")
	add()
	add(
		"S87 zmienia liczby gry powyżej 20. poziomu (plan balansu C, D): krzywe potworów, Elit i EXP w `Data/LevelCurves` (kotwice 45 / 70 / 100 tymczasowe: S92 / S93 / S94), tabele regionów `elitePairChance` i `dropFactor` (neutralne), wybór ataku bossa `Logic/BossSchedule` (gra i model), stałe `Data/BossTuning`, limit skali linii `pct` na ilvl 20 (`Bonuses.scaling`), broń dwuręczna (`Rarities.twoHandedBonusMul`, `upgradeStatPerLevelTwoHanded`), `Config.Upgrade.goldHigh` 20 i Rdzeń od +8, progi mikstur 45 / 70, kotwice `manaCost.Mage` i `heal`, zastępczy Mityk. Blok globalny `balance.spec` asertuje G1–G13 poza `GLOBAL_REPORT_ONLY` (tabela (j)). Wartości „przed” są w tabelach pasm (strzałki wobec migawki S87)."
	)
	add()

	-- (a) curves
	local curveIds = {
		"monsterHp",
		"monsterAtk",
		"eliteHp",
		"eliteDmg",
		"elite2Hp",
		"elite2Dmg",
		"expToNext",
		"manaCost.Mage",
		"heal",
	}
	local rows = {}
	for L = 20, 100, 5 do
		local cells = { tostring(L) }
		for _, id in curveIds do
			table.insert(cells, fmtValue(LevelCurves.at(id, L), "2"))
		end
		table.insert(rows, cells)
	end
	local head = { "poziom" }
	for _, id in curveIds do
		table.insert(head, `\`{id}\``)
	end
	add("### (a) Krzywe poziomu")
	add()
	add("Krzywe liczą się od poziomu końcowego potwora (Elita +2, Elita II +4); 1 do 20. poziomu.")
	add()
	tableOut(head, rows)

	-- (b) G1-G3, G6
	add("### (b) G1–G3 i G6 na 20 / 45 / 70 / 100")
	add()
	add("Wartości po S87; „przed” w tabelach G1 / G2–G3 pasm (strzałki wobec migawki S87).")
	add()
	rows = {}
	local byKey: { [string]: B.TargetRow } = {}
	for _, row in globalRows do
		byKey[`{row.id}|{row.classId}|{row.level}`] = row
	end
	for _, c in B.CLASSES do
		for _, L in { 20, 45, 70, 100 } do
			local function v(id: string, fmt: string): string
				local row = byKey[`{id}|{c}|{L}`]
				return if row then fmtValue(row.value, fmt) else "–"
			end
			table.insert(rows, {
				`{BalanceTables.CLASS_PL[c]} {L}`,
				v("G1.s", "1"),
				v("G1.hp", "%"),
				v("G2.avg", "%"),
				v("G2.size4", "%"),
				v("G3", "%"),
			})
		end
	end
	tableOut({ "klasa, poziom", "G1 s", "G1 HP", "G2 średnio", "G2 grupa 4", "G3" }, rows)
	local g6 = {}
	for _, L in { 20, 45, 70, 100 } do
		local row = byKey[`G6|nil|{L}`]
		table.insert(g6, `{L}: {if row then fmtValue(row.value, "2") else "–"}`)
	end
	add(`G6 (rozrzut czasu 1 na 1, ≤ 2,2): {table.concat(g6, ", ")}.`)
	add()

	-- (c) Elites
	add("### (c) Elita ogólna pojedyncza (raport, cel regionów 20–36 s i 55–95% HP)")
	add()
	rows = {}
	for _, c in B.CLASSES do
		local cells = { BalanceTables.CLASS_PL[c] }
		for _, L in { 20, 45, 70, 100 } do
			local f = B.elite(B.cachedPlayer(c, L), B.GENERIC, L)
			table.insert(cells, `{fmtValue(f.seconds, "1")} s / {fmtValue(f.hpLost, "%")}`)
		end
		table.insert(rows, cells)
	end
	tableOut({ "klasa", "20", "45", "70", "100" }, rows)

	-- (d) boss schedule
	add("### (d) Harmonogram bossów: kolejność listy (S83) → `BossSchedule` (S87), G11")
	add()
	rows = {}
	for _, def in Bosses.list do
		for phase = 1, #def.phases + 1 do
			local old = B.bossCadence(def, phase, { pick = B.PICK_LIST_ORDER })
			local new = B.bossCadence(def, phase)
			for _, attack in def.attacks do
				if new.perMinute[attack.id] then
					table.insert(rows, {
						`{def.id} f{phase} {attack.id}`,
						`{fmtValue(old.perMinute[attack.id], "1")} → {fmtValue(new.perMinute[attack.id], "1")}`,
						`{fmtValue(old.rateShare[attack.id], "%")} → {fmtValue(new.rateShare[attack.id], "%")}`,
						`{fmtValue(old.casting, "%")} → {fmtValue(new.casting, "%")}`,
					})
				end
			end
		end
	end
	tableOut({ "atak", "na minutę", "tempo / odnowienie (G11 ≥ 50%)", "rzucanie" }, rows)

	-- (e) items
	add("### (e) Przedmioty: G7 po limicie skali, G8, G9, Rdzenie")
	add()
	rows = {}
	for _, c in B.CLASSES do
		local cells = { BalanceTables.CLASS_PL[c] }
		for _, L in { 20, 45, 70, 100 } do
			local leg = B.rarityGainAt(c, L, Rarities.LEGENDARY).traits
			local myth = B.rarityGainAt(c, L, Rarities.MYTHIC).traits
			table.insert(cells, `{fmtValue(leg, "%")} / {fmtValue(myth, "%")}`)
		end
		table.insert(rows, cells)
	end
	add("G7 (z cechami) Legenda / Mityk:")
	add()
	tableOut({ "klasa", "20", "45", "70", "100" }, rows)
	add(
		`G8: broń dwuręczna (bez drugiej ręki) wobec zestawu domyślnego, MIX moc²; linie zwykłe ×{fmtValue(
			Rarities.twoHandedBonusMul,
			"2"
		)}, baza +{fmtValue(Rarities.upgradeStatPerLevelTwoHanded * 100, "1")}% na poziom ulepszenia. Komórka: bez cech / z cechami / luka cechy (z / bez). Pasmo 0,97–1,035 (Kostur Święty +9 do 1,06).`
	)
	add()
	rows = {}
	for _, pair in B.G8_PAIRS do
		for _, rarity in B.GEAR_RARITIES do
			for _, up in { 0, 9 } do
				local cells = { `{pair.classId} {pair.weapon} {Rarities.get(rarity).key} +{up}` }
				for _, L in B.ITEM_LEVELS do
					local low, high = B.g8Band(pair.weapon, up)
					local no = B.twoHandedParity(pair.classId, L, pair.weapon, rarity, up, { traits = false }).mix
					local yes = B.twoHandedParity(pair.classId, L, pair.weapon, rarity, up).mix
					local noText = fmtValue(no, "2")
					if no < low or no > high then
						noText = `**{noText}**`
					end
					table.insert(cells, `{noText} / {fmtValue(yes, "2")} / {fmtValue(yes / no, "2")}`)
				end
				table.insert(rows, cells)
			end
		end
	end
	tableOut({ "para", "20", "45", "70", "100" }, rows)
	rows = {}
	for _, L in { 20, 25, 30, 45, 60, 70, 80, 100 } do
		local u = B.upgradeVsIncome(L)[1]
		table.insert(rows, { tostring(L), fmtValue(u.up3, "2"), fmtValue(u.up9, "1"), fmtValue(u.goldEq9, "1") })
	end
	add(
		"G9 (Wojownik, broń domyślna ilvl − 2, Zwykła): +1…+3 / dochód poziomu (0,45–1,05), +1…+9 z ochroną w poziomach dochodu (12–25):"
	)
	add()
	tableOut({ "poziom", "+1…+3 / dochód", "+1…+9 z ochroną", "+1…+9 z materiałami" }, rows)
	rows = {}
	for _, L in { 45, 70, 100 } do
		local ilvl = L - B.GEAR_GAP
		local item = B.makeItem(B.tierId("sword1h", ilvl), ilvl, Rarities.LEGENDARY, 0, {})
		local old = B.upgradePlan(item, 9, true, { coreFrom = 7 })
		local new = B.upgradePlan(item, 9, true)
		local oldFree = B.upgradePlan(item, 9, false, { coreFrom = 7 })
		local newFree = B.upgradePlan(item, 9, false)
		table.insert(rows, {
			tostring(L),
			`{fmtValue(old.cores, "1")} → {fmtValue(new.cores, "1")}`,
			`{fmtValue(oldFree.cores, "1")} → {fmtValue(newFree.cores, "1")}`,
			`{fmtValue(old.scrolls, "1")} → {fmtValue(new.scrolls, "1")}`,
		})
	end
	add("Legenda +9: Rdzenie Legendy od +7 → od +8 i zwoje ochrony:")
	add()
	tableOut({ "poziom", "Rdzenie z ochroną", "Rdzenie bez ochrony", "zwoje" }, rows)

	-- (f) hours
	add("### (f) Godziny pasm i G13")
	add()
	rows = {}
	for _, band in B.BAND_HOURS do
		local pace = B.paceBand("Warrior", band[1], band[2])
		table.insert(rows, {
			`{band[1]}–{band[2]}`,
			fmtValue(pace.hours, "1"),
			`{fmtValue(band[3] * (1 - B.BAND_HOURS_TOLERANCE), "1")}–{fmtValue(
				band[3] * (1 + B.BAND_HOURS_TOLERANCE),
				"1"
			)}`,
		})
	end
	tableOut({ "pasmo", "godzin (Wojownik, z zadaniami)", "cel D4 ±25%" }, rows)
	add(
		"Krzywa `expToNext` zostaje neutralna (1 / 1 / 1): sama krzywa potworów wydłużyła pasma; 20–45 ponad celem idzie do S92 (kotwica 45 nie może zejść poniżej 1)."
	)
	add()

	-- (g) potions
	add("### (g) Mikstury (sprawdzenie bez zmiany odstępu, raport dla S92–S94)")
	add()
	rows = {}
	for L = 25, 100, 5 do
		local cells = { tostring(L) }
		for _, c in { "Warrior", "Mage" } do
			local rest = B.paceAt(c, L)
			local chain = B.paceAt(c, L, { potions = "chain" })
			local eco = B.economyAt(c, L, { potions = "chain" })
			table.insert(cells, fmtValue(chain.expPerHour / math.max(1e-9, rest.expPerHour), "2"))
			table.insert(cells, fmtValue(eco.potionShare, "%"))
		end
		table.insert(rows, cells)
	end
	tableOut(
		{
			"poziom",
			"Wojownik EXP/h łańcuch / odpoczynek",
			"Wojownik mikstury / dochód",
			"Mag EXP/h",
			"Mag mikstury / dochód",
		},
		rows
	)
	rows = {}
	for _, L in { 45, 70, 100 } do
		local def, f = B.bossFightAt("Warrior", L)
		table.insert(
			rows,
			{
				`{def.id} ({L})`,
				fmtValue(f.potionHps, "i"),
				fmtValue(f.tankDps, "i"),
				fmtValue(f.potionHps / math.max(1e-9, f.tankDps), "%"),
			}
		)
	end
	add("Mikstura HP/s tanka wobec obrażeń tanka bossa (drużyna 3):")
	add()
	tableOut({ "boss", "mikstura HP/s", "obrażenia tanka /s", "pokrycie" }, rows)

	-- (h) G10
	add("### (h) G10: mana Maga i leczenie Kapłana")
	add()
	rows = {}
	local g10 = SkillModel.targetsG10()
	for _, row in g10 do
		if row.report == nil then
			table.insert(rows, {
				row.label,
				fmtValue(row.value, "2"),
				`{bound(row.low)}–{bound(row.high)}`,
				if B.inBand(row) then "w paśmie" else "**poza**",
			})
		end
	end
	tableOut({ "wiersz", "wartość", "próg", "wynik" }, rows)

	-- (i) Mythic substitute
	add("### (i) Mityk z bossa: nazwany i wylosowany dla klasy")
	add()
	add(
		"500 Mityków na bossa i klasę (szansa Mityka 1, ziarno 87): udział nazwanych; każdy Mityk pasuje klasie (test `rarities.spec`)."
	)
	add()
	rows = {}
	local Loot = require("../src/shared/Logic/Loot")
	local LootTables = require("../src/shared/Data/LootTables")
	local Rng = require("../src/shared/Logic/Rng")
	local Items = require("../src/shared/Data/Items")
	for _, def in Bosses.list do
		local boss = LootTables.bosses[def.id]
		if boss then
			local always = table.clone(boss) :: any
			always.mythicChance = 1
			always.legendaryChance = 0
			local cells = { def.id }
			for _, c in B.CLASSES do
				local rng = Rng.new(87)
				local named = 0
				for _ = 1, 500 do
					local drop = Loot.rollBossItem(always, 0, c, rng) :: any
					if (Items.get(drop.defId) :: any).fixedBonuses then
						named += 1
					end
				end
				table.insert(cells, fmtValue(named / 500, "%"))
			end
			table.insert(rows, cells)
		end
	end
	local head2 = { "boss" }
	for _, c in B.CLASSES do
		table.insert(head2, BalanceTables.CLASS_PL[c])
	end
	tableOut(head2, rows)

	-- (j) report-only rows
	add("### (j) `GLOBAL_REPORT_ONLY` (wiersze w raporcie i ich sesje)")
	add()
	local groups: { [string]: { count: number, out: number, session: string, why: string } } = {}
	local order = {}
	local all = table.clone(globalRows)
	for _, row in g10 do
		table.insert(all, row)
	end
	for _, row in all do
		local entry = B.reportOnlyFor(row)
		if entry and row.report == nil then
			local key = `{row.id}|{entry.session}|{entry.why}`
			local g = groups[key]
			if not g then
				g = { count = 0, out = 0, session = entry.session, why = entry.why }
				groups[key] = g
				table.insert(order, key)
			end
			g.count += 1
			g.out += if B.inBand(row) then 0 else 1
		end
	end
	rows = {}
	for _, key in order do
		local g = groups[key]
		table.insert(rows, { string.match(key, "^[^|]+") or key, tostring(g.count), tostring(g.out), g.session, g.why })
	end
	tableOut({ "cel", "wiersze", "poza pasmem", "sesja", "powód" }, rows)
end

-- Items, traits and defence (S88) ----------------------------------------------------------------------------------

do
	local ItemRoll = require("../src/shared/Logic/ItemRoll")
	local Bonuses = require("../src/shared/Data/Bonuses")
	local Families = require("../src/shared/Data/Families")
	local Items = require("../src/shared/Data/Items")
	local s88 = SkillModel.targetsS88()
	local LEVELS = { 20, 45, 70, 100 }
	local function pct(v: number): string
		return if v ~= v then "–" else fmtValue(v * 100, "1") .. "%"
	end
	local function bandText(low: number?, high: number?, f: (number) -> string): string
		return if low and high then `{f(low)}–{f(high)}` elseif low then `≥ {f(low)}` else `≤ {f(high :: number)}`
	end

	add("## Przedmioty, cechy i obrona (S88)")
	add()
	add(
		"S88 stroi cechy broni, linie przedmiotów, obronę potworów i szczęście na 20–100 (STATY 2A–10, 14; ankieta: odpowiedzi 6, 18, 21, 23, 25). Wartość cechy = M(z cechą) / M(bez tej cechy) − 1 na buildzie wzorcowym ścieżki z wiersza STATY 3 (`Balance.TRAIT_TARGETS`), ekwipunek konwencji S32 (Zwykły +0, ilvl = poziom − 2), sytuacje z równą wagą; model umiejętności na zdarzeniu (`SkillModel.traitTarget`), sześć cech obronnych przez `Balance.traitTerms` z sytuacją zmierzoną na buildzie. Asercje: blok „Balance 20-100: items, traits, defence (S88)” w `tests/balance.spec.luau` (wiersze bez sesji w kolumnie „kto”)."
	)
	add()

	-- Traits
	add("### Cechy broni (S88)")
	add()
	add(
		"Zwykły +0 na 20 / 45 / 70 / 100 (20. tylko raport, dla S91) i Mityczny +9; pasmo 4–6% (dwuręczne Maga i Kapłana po E6 do 9%). „Węzły” = z węzłami wzmacniającymi cechę (≤ 8%), „raport” = sytuacje drukowane (zero strukturalne modelu: fale bossa to grupa, Uzdrowiciel nie traci HP w pojedynku)."
	)
	add()
	local rows = {}
	for _, row in B.TRAIT_TARGETS do
		local byL: { [number]: any } = {}
		local myth: { [number]: any } = {}
		for _, L in LEVELS do
			byL[L] = SkillModel.traitTarget(row, L)
			if L ~= 20 then
				myth[L] = SkillModel.traitTarget(row, L, Rarities.MYTHIC, 9)
			end
		end
		for i, v in byL[45].values do
			local cells = {
				`{row.trait}{if v.element then " " .. v.element else ""}`,
				`{row.build}@{row.weapon}{if row.offhand then " + " .. row.offhand else ""}`,
				table.concat(row.situations, ", "),
			}
			for _, L in LEVELS do
				local value = byL[L].values[i].value
				local band = byL[L].band
				local text = pct(value)
				if L ~= 20 and (value < band[1] or value > band[2]) then
					text = `**{text}**`
				end
				table.insert(cells, text)
			end
			local mythic = {}
			for _, L in { 45, 70, 100 } do
				table.insert(mythic, pct(myth[L].values[i].value))
			end
			table.insert(cells, table.concat(mythic, " / "))
			local nodes = {}
			for _, L in { 45, 70, 100 } do
				local n = byL[L].values[i].nodes
				if n then
					table.insert(nodes, pct(n))
				end
			end
			table.insert(cells, if #nodes > 0 then table.concat(nodes, " / ") else "–")
			local rep = {}
			for name in byL[70].report do
				table.insert(rep, `{name} {pct(byL[70].report[name])}`)
			end
			table.insert(cells, if #rep > 0 then table.concat(rep, ", ") .. " (70)" else "–")
			local reportOnly = row.reportWhy ~= nil
				and (
					row.reportElements == nil or (v.element ~= nil and table.find(row.reportElements, v.element) ~= nil)
				)
			-- S89: `reportAt` makes only some levels report-only (the rest stays asserted, as in SkillModel.targetsS88)
			local reportLevels = {}
			if reportOnly then
				for _, L in { 45, 70, 100 } do
					if row.reportAt == nil or table.find(row.reportAt, L) ~= nil then
						table.insert(reportLevels, tostring(L))
					end
				end
			end
			local who = "S88"
			if #reportLevels == 3 then
				who = `raport → {row.reportSession or "S88"}`
			elseif #reportLevels > 0 then
				who = `S88; raport → {row.reportSession or "S88"} ({table.concat(reportLevels, ", ")})`
			end
			table.insert(cells, who)
			table.insert(rows, cells)
		end
	end
	tableOut(
		{
			"cecha",
			"build",
			"sytuacje",
			"20",
			"45",
			"70",
			"100",
			"Mityczny +9 (45 / 70 / 100)",
			"z węzłami",
			"raport",
			"kto",
		},
		rows
	)
	add("Powody wierszy w raporcie (H4):")
	add()
	for _, row in B.TRAIT_TARGETS do
		if row.reportWhy then
			add(`- {row.trait}: {row.reportWhy} → {row.reportSession or "S88"}.`)
		end
	end
	add()

	-- Weapon sets of a path
	add("### Typy broni w ścieżkach")
	add()
	add(
		"Zestawy broni jednej ścieżki w `Balance.MIX` (grupa 0,5, Elita 0,3, boss 0,2) wobec pierwszego zestawu; miara ścieżki: DPS (ścieżki bojowe), moc √(DPS × EHP) (Strażnik, Chorąży, Zwiadowca, Kapłan Fortuny), Uzdrowiciel: średnia leczenia w lochu i DPS na 1 celu. Próg: max / min − 1 ≤ 5%."
	)
	add()
	rows = {}
	for _, entry in B.TYPE_SETS do
		for _, L in { 45, 70, 100 } do
			local r = SkillModel.typeSets(entry, L)
			local parts = {}
			for _, set in r.sets do
				table.insert(parts, `{set.label} {fmtValue(set.index, "2")}`)
			end
			local reportOnly = entry.reportWhy ~= nil
				and (entry.reportAt == nil or table.find(entry.reportAt, L) ~= nil)
			local spread = pct(r.spread)
			if r.spread > B.TYPE_SET_MAX then
				spread = `**{spread}**`
			end
			table.insert(rows, {
				`{entry.path} · {L}`,
				table.concat(parts, ", "),
				spread,
				if reportOnly then `raport → {entry.reportSession or "S88"}` else "S88",
			})
		end
	end
	tableOut({ "ścieżka · poziom", "zestawy (indeks w MIX)", "rozrzut", "kto" }, rows)
	for _, entry in B.TYPE_SETS do
		if entry.reportWhy then
			add(`- {entry.path}: {entry.reportWhy} → {entry.reportSession or "S88"}.`)
		end
	end
	add()

	-- Monster defence
	add("### Obrona potworów")
	add()
	add(
		"Udział pancerza i odporności magicznej w obrażeniach ataku podstawowego gracza poziomu L w potwora poziomu L (`Damage.reduction`); cel: zwykły 15–21%, opancerzony (×1,8) 25–33%, odporność zwykła 12–17%, ×1,8 21–27% (STATY 7, S66). Czas walki 1 na 1 z rodzajami z cechą obrony wobec zwykłego i EXP na sekundę walki wobec zwykłego (ta sama nagroda; poprawki nagród to S92–S94)."
	)
	add()
	rows = {}
	for _, L in LEVELS do
		local cells = { tostring(L) }
		for _, entry in B.defenceKinds() do
			local m = B.monster(entry.kind, L)
			table.insert(cells, `{pct(B.armorShare(m, L, false))} / {pct(B.armorShare(m, L, true))}`)
		end
		table.insert(rows, cells)
	end
	local head = { "poziom" }
	for _, entry in B.defenceKinds() do
		table.insert(head, `{entry.id} (pancerz / odp.)`)
	end
	tableOut(head, rows)
	rows = {}
	for _, c in B.CLASSES do
		for _, L in { 45, 70, 100 } do
			local list = B.defenceAt(c, L)
			local cells = { `{BalanceTables.CLASS_PL[c]} {L}` }
			for _, d in list do
				table.insert(
					cells,
					`{fmtValue(d.seconds / list[1].seconds, "2")} / {fmtValue(list[1].seconds / d.seconds, "2")}`
				)
			end
			table.insert(rows, cells)
		end
	end
	head = { "klasa, poziom" }
	for _, entry in B.defenceKinds() do
		table.insert(head, `{entry.id} (czas / EXP/s)`)
	end
	tableOut(head, rows)
	rows = {}
	for _, L in { 45, 70, 100 } do
		for _, v in B.vsDefence(L) do
			table.insert(rows, { `{v.label} · {L}`, pct(v.generic), pct(v.defended) })
		end
		local acc = ItemRoll.rollBonusValue("accuracy", L - B.GEAR_GAP, Rarities.LEGENDARY, 0.5)
		table.insert(rows, {
			`linia accuracy (Legendarny, środek rzutu {fmtValue(acc, "1")}) · {L}`,
			"0%",
			pct(acc / 100),
		})
	end
	tableOut({ "przeciw obronie: zysk DPS", "zwykły", "opancerzony / zwinny (unik zdjęty)" }, rows)
	local beast = Families.defence("beast", "agile") :: any
	local animal = Families.defence("animal", "agile") :: any
	add(
		`Unik: harpia (beast) {beast.dodge}% (S88: 15 → 10), ryś / nietoperz / lampart (animal) {animal.dodge}% (wspólny z rysiem z Łąk; S91). Bossowie bez zmian (S66; życie i ataki S92–S94).`
	)
	add()

	-- Lines and rarity
	add("### Linie i rzadkość")
	add()
	rows = {}
	for _, t in B.LINE_TARGETS do
		local id = if t.over == "family"
			then Bonuses.familyLine(t.prefix :: any, Families.ids[1])
			else Bonuses.classLine(t.prefix :: any, "Warrior")
		local parts = {}
		for _, r in { Rarities.COMMON, Rarities.LEGENDARY, Rarities.MYTHIC } do
			local lo, hi = ItemRoll.bonusRange(id, 100, r)
			table.insert(parts, `{fmtValue(lo, "1")}–{fmtValue(hi, "1")}`)
		end
		local lo2, hi2 = ItemRoll.bonusRange(id, 100, Rarities.COMMON)
		table.insert(rows, {
			`{t.prefix}<{if t.over == "family" then "rodzina" else "klasa"}>`,
			parts[1],
			parts[2],
			parts[3],
			`{fmtValue(t.common[1], "1")}–{fmtValue(t.common[2], "1")} (Mityk ≤ {fmtValue(t.mythicTop, "1")})`,
			-- only vs_<family> rolls on weapons (S67 pools: weapon, necklace)
			if t.prefix == "vs_" and t.over == "family"
				then `{fmtValue(lo2 * Rarities.twoHandedBonusMul, "1")}–{fmtValue(
					hi2 * Rarities.twoHandedBonusMul,
					"1"
				)}`
				else "–",
		})
	end
	tableOut(
		{ "linia (100. poziom)", "Zwykły", "Legenda", "Mityk", "cel (odp. 23)", "Zwykły na broni dwuręcznej" },
		rows
	)
	-- D2 parity
	rows = {}
	for _, c in B.CLASSES do
		local items = B.gear(c, 70)
		local base = B.playerFromItems(c, 70, items)
		local p0 = B.power(base, nil, { traits = true, situation = "single" }) ^ 2
		local function gain(id: string): number
			local copy = table.clone(items)
			local last = table.clone(copy[#copy])
			local bonuses = table.clone(last.bonuses)
			table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, 68, Rarities.HEROIC, 0.5) })
			last.bonuses = bonuses
			copy[#copy] = last
			return B.power(B.playerFromItems(c, 70, copy), nil, { traits = true, situation = "single" }) ^ 2 / p0 - 1
		end
		local atk = gain(if c == "Mage" or c == "Cleric" then "magAtk" else "physAtk")
		local parts = {}
		for _, id in
			{
				"pierce",
				"magicPierce",
				"skillDmg",
				"basicDmg",
				"critResist",
				"poisonChance",
				"woundChance",
				"dotPower",
				"blockChance",
			}
		do
			local g = gain(id)
			if g ~= 0 then
				table.insert(parts, `{id} {fmtValue(g / atk, "2")}`)
			end
		end
		table.insert(rows, { BalanceTables.CLASS_PL[c], table.concat(parts, ", ") })
	end
	add(
		"Parytet linii (D2, raport): zysk mocy² jednej linii średniego rzutu (Heroiczny, 70. poziom, `single`) wobec linii ataku klasy; kandydat do zmiany poza 0,5–2,0."
	)
	add()
	tableOut({ "klasa", "linia / linia ataku" }, rows)
	add(
		"G7 (zysk pełnego zestawu rzadkości wobec Zwykłego, z cechami, `single`): asertuje blok globalny S87 (tabela „Cele G7–G9” wyżej i „(j)”)."
	)
	add()

	-- Named Mythics
	add("### Nazwane Mityczne")
	add()
	add(
		`Moc w MIX postaci klasy docelowej z nazwanym przedmiotem w slocie / z oczekiwanym wylosowanym Mitykiem tego samego typu i ilvl (definicja diagnozy S84 F); cel {fmtValue(
			B.NAMED_BAND[1],
			"2"
		)}–{fmtValue(B.NAMED_BAND[2], "2")}. Linie zwykłe ≤ {fmtValue(B.NAMED_LINE_MAX, "1")} × górna granica Mityczna (broń dwuręczna × \`twoHandedBonusMul\`), legendarna w swoim zakresie.`
	)
	add()
	rows = {}
	local named = {}
	for id in B.NAMED_TARGETS do
		table.insert(named, id)
	end
	table.sort(named)
	for _, id in named do
		local def = Items.get(id) :: any
		local powers = {}
		local sum = 0
		for _, c in B.NAMED_TARGETS[id] do
			local p = B.namedPower(id, c).power
			sum += p
			table.insert(powers, `{BalanceTables.CLASS_PL[c]} {fmtValue(p, "2")}`)
		end
		local lines = {}
		for _, l in B.namedLines(id) do
			table.insert(
				lines,
				`{l.stat} {fmtValue(l.v, "1")} (≤ {fmtValue(l.limit, "1")}){if l.ok then "" else " **!**"}`
			)
		end
		local mean = sum / #B.NAMED_TARGETS[id]
		local meanText = fmtValue(mean, "2")
		if mean < B.NAMED_BAND[1] or mean > B.NAMED_BAND[2] then
			meanText = `**{meanText}**`
		end
		table.insert(
			rows,
			{ `{id} ({def.type}, {def.level})`, meanText, table.concat(powers, ", "), table.concat(lines, ", ") }
		)
	end
	tableOut({ "przedmiot", "moc / wylosowany Mityk", "klasy", "linie" }, rows)

	-- Class checks
	add("### Kontrole klasowe")
	add()
	rows = {}
	for _, L in { 45, 70, 100 } do
		for _, key in { "guardian.loner", "guardian.defender" } do
			for _, w in { "sword1h", "saber1h", "axe1h", "mace1h" } do
				local g = SkillModel.guardLimits(key, w, L)
				table.insert(rows, {
					`{key}@{w} · {L}`,
					`{fmtValue(g.block, "1")} / {Combat.blockCap}`,
					`{fmtValue(g.riposte, "1")} / {Combat.riposteCap}`,
					`{pct(g.avoid)} / {Combat.dodgeCap + Combat.avoidBonus}%`,
					if g.ehp > B.GUARD_EHP_MAX then `**{pct(g.ehp)}**` else pct(g.ehp),
					fmtValue(g.blockHealPerSecond, "2") .. "%",
				})
			end
		end
	end
	add(
		"Strażnik (E1): blok i kontra przed limitem, unik + chybienie + blok przed cięciem w `Damage.avoidance`, wkład obu cech zestawu w EHP (≤ 12%; topór i buława w raporcie → S89), leczenie z bloku w % maks. HP/s."
	)
	add()
	tableOut(
		{
			"build, broń · poziom",
			"blok / limit",
			"kontra / limit",
			"unik+blok / limit",
			"EHP obu cech",
			"leczenie z bloku / s",
		},
		rows
	)
	rows = {}
	for _, L in { 45, 70, 100 } do
		for _, r in { { Rarities.COMMON, 0 }, { Rarities.MYTHIC, 9 } } do
			local e = SkillModel.executeCheck(L, r[1], r[2])
			table.insert(rows, {
				`{e.gear} · {L}`,
				fmtValue(e.trait, "1"),
				fmtValue(e.node, "1"),
				`{fmtValue(e.trait + e.node, "1")} / {e.cap}`,
				fmtValue(e.withLines, "1"),
				fmtValue(e.cut, "1"),
			})
		end
	end
	add(
		"Ścięcie i Kat (E3, „Furia” z `sword2h`): suma cechy i węzła pod `executionerCap`; z liniami `leg_executioner` 18 i `myth_executioner` 35 (górne granice) limit ucina resztę."
	)
	add()
	tableOut({ "przedmiot · poziom", "Ścięcie", "Kat", "razem / limit", "z liniami", "ucięte" }, rows)
	rows = {}
	for _, L in { 45, 70, 100 } do
		local healer = SkillModel.byKey("healer.dungeon")
		local tank = SkillModel.defenderTank(L)
		local s0 = SkillModel.savingSelf(L, Rarities.COMMON, 0)
		local s9 = SkillModel.savingSelf(L, Rarities.MYTHIC, 9)
		table.insert(rows, {
			tostring(L),
			fmtValue(SkillModel.oneHeal(healer, L, tank), "2"),
			fmtValue(SkillModel.oneHeal(healer, L, tank, { rarity = Rarities.MYTHIC, up = 9 }), "2"),
			`{fmtValue(s0.total, "1")} / {s0.cap}`,
			`{fmtValue(s9.total, "1")} / {s9.cap}`,
		})
	end
	add(
		"Uzdrowiciel (E4): T-SK5 (jedno Leczenie / maks. HP Obrońcy, cel 0,25–0,35) z Namaszczeniem Zwykłym i Mitycznym +9; Zbawczy cios na noszącym + wampiryzm w limicie kradzieży życia."
	)
	add()
	tableOut(
		{ "poziom", "T-SK5 Zwykły", "T-SK5 Mityczny +9", "Zbawczy cios + wampiryzm Zwykły", "Mityczny +9" },
		rows
	)
	rows = {}
	for _, L in { 45, 70, 100 } do
		for _, k in SkillModel.killHealSums(L) do
			table.insert(rows, {
				`{k.label} · {L}`,
				fmtValue(k.raw, "1") .. "%",
				fmtValue(k.capped, "1") .. "%",
				fmtValue(k.lossPerKill, "1") .. "%",
				fmtValue(k.waves, "i") .. "%",
			})
		end
	end
	add(
		"Leczenie za zabicie (E5): suma haka `killHeal` i po limicie `Traits.killHeal` (limit kradzieży życia 15%), utrata HP na zabicie w G1 i leczenie z ok. 20 zabić fal bossa."
	)
	add()
	tableOut({ "suma · poziom", "surowa", "po limicie", "utrata HP / zabicie (G1)", "fale bossa" }, rows)

	-- PvP
	add("### PvP")
	add()
	add(
		"Pojedynek graczy tego samego poziomu (`Balance.pvpDuel`, konwencja S32: atak podstawowy + umiejętności ×1,2, buildy S86 ze statystykami i węzłami): `pvpModifier` raz na ciosach, tyknięcia ×0,6 raz, połowy bloku, kontry, kradzieży życia i cech warunkowych, kontrola o połowę krótsza. Czas zabicia w sekundach z cechami (bez cech / z liniami klas napastnika). Kontrakty nie dają celu bezwzględnego (lista „Dla właściciela”)."
	)
	add()
	for _, L in { 45, 70, 100 } do
		rows = {}
		for _, a in SkillModel.PVP_ATTACKERS do
			local cells = { a }
			for _, d in SkillModel.PVP_DEFENDERS do
				local r = SkillModel.pvpPair(a, d, L)
				table.insert(
					cells,
					`{fmtValue(r.seconds, "1")} ({fmtValue(r.noTraits, "1")} / {fmtValue(r.classLines, "1")})`
				)
			end
			table.insert(rows, cells)
		end
		local headP = { `napastnik → obrońca, {L}` }
		for _, d in SkillModel.PVP_DEFENDERS do
			table.insert(headP, d)
		end
		tableOut(headP, rows)
	end
	rows = {}
	for _, t in SkillModel.PVP_HALF_TRAITS do
		local cells = { t }
		for _, L in { 45, 70, 100 } do
			local h = SkillModel.pvpHalf(t, L)
			table.insert(cells, `{pct(h.pvp)} / {pct(h.pve)} = {fmtValue(h.ratio, "2")}`)
		end
		table.insert(rows, cells)
	end
	add("Cechy warunkowe i obronne (STATY 8): wartość w PvP / w PvE w pojedynku lustrzanym (≤ 0,55).")
	add()
	tableOut({ "cecha", "45", "70", "100" }, rows)
	add(
		`Ogłuszenie Wstrząsem: {pct(SkillModel.pvpStun(45))} / {pct(SkillModel.pvpStun(70))} / {pct(
			SkillModel.pvpStun(100)
		)} czasu walki (≤ 2%); tyknięcie umiejętności PvP / PvE {fmtValue(SkillModel.pvpTickRatio(70), "2")}.`
	)
	add()

	-- Luck and D5
	add("### Szczęście i drop (D5)")
	add()
	add(
		"Wojownik na expowisku swojego poziomu (`Balance.dropsPerHour`): Unikaty dla klasy na godzinę expienia, Heroiki dla klasy na godzinę Elit w jaskiniach, Legenda z Elity II (×`elite2Mul`), szczęście przed limitem i ucięte przez limit `monsterItemCap` (100). K0 poza pasmem D5 (Unikat 2–4, Heroik 0,5–1,5) stroją S92–S94 przez `dropFactor` regionu. Szansa przedmiotu z Elity 0,75 ucina premię ponad +33% (kolumna „ucięte na Elicie”)."
	)
	add()
	rows = {}
	for _, L in { 45, 70, 100 } do
		for _, k in { "K0", "K1", "K2", "K3" } do
			for _, f in { false, "full" } do
				local d = B.dropsPerHour("Warrior", L, k, f :: any)
				table.insert(rows, {
					`{k}{if f then " + Fortuna" else ""} · {L}`,
					fmtValue(d.unique, "2"),
					fmtValue(d.heroic, "2"),
					fmtValue(d.legendaryPerElite2, "2"),
					fmtValue(d.beforeCap, "i"),
					fmtValue(d.capCut, "i"),
					fmtValue(d.eliteCut, "i"),
				})
			end
		end
	end
	tableOut(
		{
			"profil · poziom",
			"Unikaty / h",
			"Heroiki / h",
			"Legenda / Elita II",
			"szczęście przed limitem",
			"ucięte przez limit",
			"ucięte na Elicie",
		},
		rows
	)
	local relic = function(r: number, up: number): number
		local item = B.makeItem(B.tierId("relic", 68), 68, r, up, {})
		return (ItemRoll.trait(item) :: any).value
	end
	add(
		`Pomyślność (relikwia Kapłana Fortuny): +{fmtValue(relic(Rarities.COMMON, 0), "1")}% (Zwykła) do +{fmtValue(
			relic(Rarities.MYTHIC, 9),
			"1"
		)}% (Mityczna +9) szansy na przedmiot, czyli ×{fmtValue(1 + relic(Rarities.COMMON, 0) / 100, "2")}–{fmtValue(
			1 + relic(Rarities.MYTHIC, 9) / 100,
			"2"
		)} Unikatów bez innego szczęścia; poza pasmem 4–6% (wyjątek STATY 2A, odpowiedź 12).`
	)
	add()

	-- Targets
	add("### Cele S88")
	add()
	rows = {}
	for _, row in s88 do
		local f = if string.sub(row.id, 1, 1) == "T"
				or row.id == "E1.ehp"
				or row.id == "E1.avoid"
				or row.id == "F.half"
				or row.id == "F.stun"
				or row.id == "F.ticks"
			then pct
			else function(v: number): string
				return fmtValue(v, "2")
			end
		table.insert(rows, {
			`{row.id} · {row.label}`,
			f(row.value),
			bandText(row.low, row.high, f),
			if B.inBand(row) then "w paśmie" else "**poza**",
			if row.report then `raport → {row.report}` else "S88 (asertowane)",
		})
	end
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, rows)
end

-- Formulas ------------------------------------------------------------------------------------------------------

add("## Wzory (stan obecny)")
add()
add(
	`- Potwór: HP = ({Combat.monsterHpBase} + {Combat.monsterHpComp}·{Combat.monsterHpFactor}·L^{Combat.monsterHpExponent}) × monsterHp(L), atak = ({Combat.monsterAtkBase} + {Combat.monsterAtkFactor}·L^{Combat.monsterAtkExponent}) × monsterAtk(L) (S87: krzywe od poziomu końcowego, 1 do 20.; Elita × eliteHp / eliteDmg), pancerz {Combat.monsterArmorPerLevel}·L × defMul, odporność magiczna {Combat.monsterMresPerLevel}·L × mresMul, atak co {Combat.monsterAttackInterval} s / szybkość.`
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
	`- Harmonogram bossa: \`Boss.Step\` co 0,05 s; gdy t ≥ nextGlobal, spośród gotowych ataków fazy ten z największą zaległością względem swojego odnowienia, (t − nextAttack) / odnowienie (S87, \`Logic/BossSchedule\`; remis: kolejność listy); potem nextAttack = t + odnowienie, nextGlobal = t + zamach + {B.BOSS_GLOBAL_GAP} s (\`Data/BossTuning\`); pierwszy atak po 4 s, pierwsze użycie każdego średnio po 5 s. Przyspieszenie fazy dzieli tylko odstęp ataku podstawowego, wściekłość mnoży wszystkie ciosy.`
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
