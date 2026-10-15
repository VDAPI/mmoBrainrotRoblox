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
--   --baseline <file>  (S94) the baseline of the full ledger S83-S94 (default tools/balance_base.json, the S83
--                    snapshot taken before the first change of the balance chain).
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
local Crafting = require("../src/shared/Data/Crafting")
local Items = require("../src/shared/Data/Items")
local LevelCurves = require("../src/shared/Logic/LevelCurves")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Progression = require("../src/shared/Data/Progression")
local ArenaData = require("../src/shared/Data/Arena")
local Rarities = require("../src/shared/Data/Rarities")
local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")
local Reasons = require("./balance_reasons")
local Exp = require("../src/shared/Logic/Exp")
local QuestBudgetData = require("../src/shared/Data/QuestBudget")
local QuestBudgetGen = require("./QuestBudgetGen")
local Quests = require("../src/shared/Data/Quests")
local SkillModel = require("../tests/SkillModel")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local ShopPrice = require("../src/shared/Logic/ShopPrice")
local Shops = require("../src/shared/Data/Shops")

local SNAPSHOT = "tools/balance_before.json"
-- S94 (M2): the baseline of the full ledger S83-S94 (`--baseline <file>`; the S83 snapshot before the chain)
local BASELINE = "tools/balance_base.json"
for i, arg in process.args do
	if arg == "--baseline" and process.args[i + 1] then
		BASELINE = process.args[i + 1]
	end
end
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
	elseif fmt == "1%" then
		text = string.format("%.1f%%", value * 100) -- S109
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

-- S94 (M1): one table of every target 1-100 (block, rows, in band, asserted, report rows by the session of their
-- reason) and the open targets 1-100 (every report row grouped by its reason).
do
	local function sessionOf(text: string?): string
		local n = if type(text) == "string" then string.match(text, "S(%d+)") else nil
		return if n then `S{n}` else "–"
	end
	local blocks: { { name: string, rows: { any } } } = {}
	local function block(name: string, rows: { any })
		table.insert(blocks, { name = name, rows = rows })
	end
	local s32, s91 = {}, {}
	for _, row in B.targets1_20() do
		table.insert(if string.sub(row.id, 1, 4) == "S32." then s32 else s91, row)
	end
	block("1–20: cele S32 (S91)", s32)
	block("1–20: cele S91", s91)
	local global: { any } = {}
	for _, row in B.targetsGlobal() do
		local copy = table.clone(row) :: any
		local entry = B.reportOnlyFor(row)
		if copy.report == nil and entry then
			copy.report = `{entry.session}: {entry.why}`
		end
		table.insert(global, copy)
	end
	for _, row in SkillModel.targetsG10() do
		table.insert(global, row)
	end
	block("20–100: globalne G1–G13 (S87)", global)
	local regionSession = { meadows = "S91", duskwood = "S92", ashen = "S93", frostpeak = "S94" }
	for _, mapId in B.REGION_IDS do
		local rows = B.targetsRegion(mapId)
		local extra = if mapId == "duskwood"
			then B.targetsS92()
			elseif mapId == "ashen" then B.targetsS93()
			elseif mapId == "frostpeak" then B.targetsS94()
			else B.targetsRegion(mapId, nil, true)
		for _, row in extra do
			table.insert(rows, row)
		end
		block(`region {mapId} ({regionSession[mapId]})`, rows)
	end
	block("1–100: wiersze przekrojowe (S94)", B.targetsCross())
	block("20–100: cechy, linie, obrona (S88)", SkillModel.targetsS88())
	local paths: { any } = {}
	for _, r in SkillModel.evaluateTargets() do
		if r.asserted then
			table.insert(paths, { id = r.id, value = r.value, report = nil, pass = r.pass })
		elseif r.report then
			table.insert(paths, { id = r.id, value = r.value, report = r.report, pass = r.pass })
		end
	end
	block("20–100: ścieżki (S89–S90)", paths)
	add("## Cele 1–100 (S94: bez bramki `TUNED`)")
	add()
	add(
		"Każdy wiersz bez opisu raportu jest asercją `balance.spec` (bloki niżej). Wiersze w trybie raportu mają powód „poza zasięgiem dźwigni S<n>” (sesja i liczby w `docs/DECYZJE.md`); ich lista po powodach jest w „Otwarte cele 1–100”."
	)
	add()
	local tRows: { { string } } = {}
	local open: { [string]: { count: number, ok: number, session: string, block: string } } = {}
	local openOrder: { string } = {}
	for _, b in blocks do
		local all, inBand, asserted = #b.rows, 0, 0
		local bySession: { [string]: number } = {}
		for _, row in b.rows do
			local pass = if row.pass ~= nil then row.pass else B.inBand(row)
			if pass then
				inBand += 1
			end
			if row.report == nil then
				asserted += 1
			else
				local text = if type(row.report) == "string" then row.report else "tylko raport"
				local s = sessionOf(text)
				bySession[s] = (bySession[s] or 0) + 1
				local key = `{b.name}|{text}`
				if not open[key] then
					open[key] = { count = 0, ok = 0, session = s, block = b.name }
					table.insert(openOrder, key)
				end
				open[key].count += 1
				open[key].ok += if pass then 1 else 0
			end
		end
		local parts = {}
		for s, n in bySession do
			table.insert(parts, `{s} {n}`)
		end
		table.sort(parts)
		table.insert(tRows, {
			b.name,
			tostring(all),
			tostring(inBand),
			tostring(asserted),
			if #parts > 0 then table.concat(parts, ", ") else "0",
		})
	end
	tableOut({ "blok", "wiersze", "w paśmie", "asertowane", "raport (sesja powodu: wiersze)" }, tRows)
	add("### Otwarte cele 1–100 (wiersze w trybie raportu, po powodach)")
	add()
	local oRows: { { string } } = {}
	for _, key in openOrder do
		local o = open[key]
		local why = string.sub(key, #o.block + 2)
		table.insert(oRows, { o.block, o.session, `{o.count - o.ok}/{o.count}`, why })
	end
	tableOut({ "blok", "sesja", "poza pasmem / wiersze", "powód" }, oRows)
end

-- Ledger --------------------------------------------------------------------------------------------------------

-- S95: rows of one reason (`why` in column `whyCol`) with at least COLLAPSE_MIN keys (a whole shop added or removed at
-- once) become one row: the keys' common prefix, "N kluczy" and "–" in the value columns.
local COLLAPSE_MIN = 100
local function collapse(rows: { { string } }, whyCol: number, valueCols: { number }): { { string } }
	local count: { [string]: number } = {}
	for _, r in rows do
		count[r[whyCol]] = (count[r[whyCol]] or 0) + 1
	end
	local prefix: { [string]: string } = {}
	for _, r in rows do
		local why = r[whyCol]
		if count[why] >= COLLAPSE_MIN then
			local key = string.gsub(r[1], "`", "")
			local p = prefix[why]
			if p == nil then
				prefix[why] = key
			else
				local n = 0
				while n < #p and n < #key and string.sub(p, n + 1, n + 1) == string.sub(key, n + 1, n + 1) do
					n += 1
				end
				prefix[why] = string.sub(p, 1, n)
			end
		end
	end
	local out: { { string } } = {}
	local done: { [string]: boolean } = {}
	for _, r in rows do
		local why = r[whyCol]
		if count[why] < COLLAPSE_MIN then
			table.insert(out, r)
		elseif not done[why] then
			done[why] = true
			local row = table.clone(r)
			row[1] = `\`{prefix[why]}…\` ({count[why]} kluczy)`
			for _, i in valueCols do
				row[i] = "–"
			end
			table.insert(out, row)
		end
	end
	return out
end

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
				tableOut({ "klucz", "wartość", "sesja", "powód" }, collapse(rows, 4, { 2 }))
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

-- S94 (M2): the full ledger S83-S94 against the baseline (`--baseline <file>`, default tools/balance_base.json = the
-- S83 snapshot taken before the first change of the chain): every key whose value moved since, with all its reasons
-- (session and why); keys the baseline does not have are marked "nowy od S<n>" (the first session of their reasons);
-- a whole module added to the ledger later (S94: Crafting, Maps) is summarised in one row.
do
	local path = BASELINE
	add("## Pełna księga S83–S94 (od migawki przed S83)")
	add()
	if not fs.isFile(path) then
		add(`Brak pliku \`{path}\` (\`--baseline <plik>\`): pełna księga pominięta.`)
		add()
	else
		local decoded = serde.decode("json", fs.readFile(path))
		local base: { [string]: number } = decoded.data or {}
		local baseMeta = decoded.meta or {}
		add(
			`Baza: \`{path}\` (migawka {baseMeta.session or "?"}, commit {baseMeta.commit or "?"}, {baseMeta.date or "?"}); teraz: dane gry. Dla każdego klucza: wartość przed S83, po S94 i wszystkie powody z \`tools/balance_reasons.luau\` (sesja: powód). Rangi (\`Rangi:\`) to liczby pochodne i ich tu nie ma.`
		)
		add()
		local baseModules: { [string]: boolean } = {}
		for key in base do
			local module = string.match(key, "^([^:]+):")
			if module then
				baseModules[module] = true
			end
		end
		local function reasonsText(key: string): (string, string)
			local list = B.reasonsFor(Reasons.reasons, key)
			if not list or #list == 0 then
				return "–", "**BRAK POWODU**"
			end
			local sorted = table.clone(list)
			table.sort(sorted, function(a: any, b: any)
				return (B.sessionNumber(a.session) or 0) < (B.sessionNumber(b.session) or 0)
			end)
			local parts = {}
			for _, entry in sorted do
				table.insert(parts, `{entry.session}: {entry.why}`)
			end
			return (sorted[1] :: any).session, table.concat(parts, "; ")
		end
		local function num(v: number?): string
			return if v == nil then "–" else fmtValue(v, "g")
		end
		local keys: { string } = {}
		for key in data do
			if string.sub(key, 1, 6) ~= "Rangi:" then
				table.insert(keys, key)
			end
		end
		for key in base do
			if data[key] == nil and string.sub(key, 1, 6) ~= "Rangi:" then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		local rows: { { string } } = {}
		local laterModules: { [string]: { count: number, changed: { string } } } = {}
		local missing = 0
		for _, key in keys do
			local before, after = base[key], data[key]
			local module = string.match(key, "^([^:]+):") or key
			if before == nil and not baseModules[module] then
				local entry = laterModules[module]
				if not entry then
					entry = { count = 0, changed = {} }
					laterModules[module] = entry
				end
				entry.count += 1
				local list = B.reasonsFor(Reasons.reasons, key)
				if list then
					local _, why = reasonsText(key)
					if not table.find(entry.changed, why) then
						table.insert(entry.changed, why)
					end
				end
			elseif before == nil or after == nil or not B.sameNumber(before, after) then
				local first, why = reasonsText(key)
				if first == "–" then
					missing += 1
				end
				local note = if before == nil then `nowy od {first}` elseif after == nil then "usunięty" else first
				table.insert(rows, { `\`{key}\``, num(before), num(after), note, why })
			end
		end
		add(`{#rows} kluczy zmienionych od bazy, {missing} bez powodu.`)
		add()
		tableOut({ "klucz", "przed S83", "po S94", "sesja", "powody (sesja: powód)" }, collapse(rows, 5, { 2, 3 }))
		local mRows: { { string } } = {}
		for module, entry in laterModules do
			table.insert(mRows, {
				module,
				tostring(entry.count),
				if #entry.changed > 0 then table.concat(entry.changed, "; ") else "bez zmian liczb",
			})
		end
		table.sort(mRows, function(a, b)
			return a[1] < b[1]
		end)
		if #mRows > 0 then
			add("### Moduły dopisane do księgi po S83")
			add()
			tableOut({ "moduł", "kluczy", "zmiany (sesja: powód)" }, mRows)
		end
	end
end

-- Rank bands ----------------------------------------------------------------------------------------------------

add("## Własność pasm umiejętności")
add()
add(
	"Ranga należy do pasma swojego poziomu `Skills.rankLevel` (≤ 20 → strojenie 1–20 S91, zamrożone; 21–45, 46–70, 71–100 →"
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

-- S92 (L1): the Dark Forest section: start S92 -> now, the S92 targets (Balance.targetsS92) and the "Tylko raport"
-- items of the session file.
local function s92Section()
	local S = B.S92
	local s92Rows = B.targetsS92()
	local byId: { [string]: B.TargetRow } = {}
	for _, row in s92Rows do
		byId[row.id] = row
	end
	local function v(id: string): number
		local row = byId[`R.duskwood.{id}`]
		return if row then row.value else 0 / 0
	end
	local function range(prefix: string, fmt: string): string
		local lo, hi = math.huge, -math.huge
		for _, row in s92Rows do
			if string.sub(row.id, 1, #prefix) == prefix then
				lo, hi = math.min(lo, row.value), math.max(hi, row.value)
			end
		end
		if lo == math.huge then
			return "–"
		end
		return `{fmtValue(lo, fmt)}–{fmtValue(hi, fmt)}`
	end
	-- "in band / all" of the S92 rows with this id prefix
	local function count(prefix: string): string
		local ok, all = 0, 0
		for _, row in s92Rows do
			if string.sub(row.id, 1, #prefix) == prefix then
				all += 1
				ok += if B.inBand(row) then 1 else 0
			end
		end
		return `{ok}/{all}`
	end
	local regionRows = B.targetsRegion("duskwood")
	local uniqueLo, uniqueHi = math.huge, -math.huge
	for _, row in regionRows do
		if row.group == "d5" and string.find(row.id, ".unique", 1, true) then
			uniqueLo, uniqueHi = math.min(uniqueLo, row.value), math.max(uniqueHi, row.value)
		end
	end
	local function regionMax(group: string, classId: string?): number
		local hi = -math.huge
		for _, row in regionRows do
			if row.group == group and (classId == nil or row.classId == classId) then
				hi = math.max(hi, row.value)
			end
		end
		return hi
	end
	local function regionMin(group: string): number
		local lo = math.huge
		for _, row in regionRows do
			if row.group == group then
				lo = math.min(lo, row.value)
			end
		end
		return lo
	end
	add("### S92: Mroczny Bór i Morvane (start S92 → teraz)")
	add()
	add(
		"Start = stan po S91 (`10f94d2`), zmierzony tym samym modelem przed zmianą danych. Cele: `docs/sessions/S92.md` → „Cele tej sesji”; wiersze asertuje blok regionów `balance.spec` (`TUNED.duskwood`, `Balance.targetsS92`), wiersze z opisem w kolumnie „kto asertuje” są w raporcie (powody: `docs/DECYZJE.md` → S92)."
	)
	add()
	local pace, h44, step = 0, B.paceWindowAt("Warrior", 44).hours, 0
	for L = 20, 44 do
		pace += B.paceWindowAt("Warrior", L).hours
		step =
			math.max(step, B.paceWindowAt("Warrior", L).hours / math.max(1e-9, B.paceWindowAt("Warrior", L - 1).hours))
	end
	local noSup = {}
	for n = 3, 5 do
		table.insert(noSup, fmtValue(v(`morvane.noSupport.{n}.seconds`), "1"))
	end
	local rows = {
		{
			"Morvane 3 / 4 / 5 graczy L44: min",
			"4,6 / 4,8 / 4,7",
			`{fmtValue(v("morvane.team3"), "2")} / {fmtValue(v("morvane.team4"), "2")} / {fmtValue(
				v("morvane.team5"),
				"2"
			)}`,
			"4–6",
		},
		{
			"Morvane: największy cios Maga L45 / L43",
			"107% / 112%",
			`{fmtValue(v("morvane.mage45"), "%")} / {fmtValue(v("morvane.mage43"), "%")}`,
			"≤ 70% / < 100%",
		},
		{ "Morvane: zwykły cios Maga L45", "28%", fmtValue(v("morvane.basic45"), "%"), "7–12%" },
		{ "Morvane: tank HP na minutę (model S32)", "770%", fmtValue(v("morvane.tank"), "%"), "≤ 350%" },
		{
			"Morvane: tank HP na minutę (bossFight, z Polem Klątwy; 3 / 4 / 5)",
			"–",
			`{fmtValue(v("morvane.tankFight3"), "%")} / {fmtValue(v("morvane.tankFight4"), "%")} / {fmtValue(
				v("morvane.tankFight5"),
				"%"
			)}`,
			"raport",
		},
		{
			"Morvane: fala tarczy, HP na członka (3 / 4 / 5; pomocnicy bez redukcji grupy)",
			"239% / 158% / 154%",
			`{fmtValue(v("morvane.wave3"), "%")} / {fmtValue(v("morvane.wave4"), "%")} / {fmtValue(
				v("morvane.wave5"),
				"%"
			)}`,
			"≤ 110%",
		},
		{
			"Morvane: T-SK6 Uzdrowiciela lochowego",
			"2,70",
			fmtValue(v("morvane.tsk6"), "2"),
			`1,0–{fmtValue(S.tsk6[2], "2")}`,
		},
		{ "Morvane bez wsparcia 3 / 4 / 5: s", "107 / 109 / 103", table.concat(noSup, " / "), "≤ 480" },
		{
			"Morvane bez wsparcia 3 / 4 / 5: przyjmowane / podtrzymanie (najgorszy)",
			"0,99 / 0,97 / 0,96",
			`{fmtValue(v("morvane.noSupport.3.sustain"), "2")} / {fmtValue(v("morvane.noSupport.4.sustain"), "2")} / {fmtValue(
				v("morvane.noSupport.5.sustain"),
				"2"
			)}`,
			"≤ 1,0",
		},
		{
			"Morvane bez wsparcia: największy cios / HP członka",
			"110%",
			fmtValue(v("morvane.noSupport.3.hit"), "%"),
			"≤ 100%",
		},
		{ "Morvane: G11 (najmniejsze tempo ataku)", "53%", fmtValue(regionMin("bossCadence"), "%"), "≥ 50%" },
		{
			"Elity: spotkanie Wojownik / Mag (najgorsze)",
			"191% / 206%",
			`{fmtValue(regionMax("eliteEncounter", "Warrior"), "%")} / {fmtValue(
				regionMax("eliteEncounter", "Mage"),
				"%"
			)}`,
			"≤ 110% / ≤ 125%",
		},
		{ "Spawnery Elit na poziomach 21–45", "18/25", count("R.duskwood.ilvl.elite"), "każdy" },
		{ "Expowiska na 43–44", "1", `{v("areas.43")} / {v("areas.44")}`, "≥ 2" },
		{ "Rodzaje: EXP/s ÷ zwykły (najmniej)", "0,80 (rotEnt)", fmtValue(regionMin("kinds"), "2"), "0,85–1,20" },
		{ "Tempo 20 → 45 (okno): h", "16,07", fmtValue(pace, "2"), "11,9–16,1" },
		{
			"G13: pasmo 20–45 (rodzaje regionu, zadania na swoim poziomie): h",
			"17,98",
			fmtValue(B.paceBand("Warrior", 20, 45).hours, "2"),
			"10,5–17,5",
		},
		{
			"Tempo: h(44) / największy krok h(L) / h(L − 1)",
			"0,93 / 1,89 (L21)",
			`{fmtValue(h44, "2")} / {fmtValue(step, "2")}`,
			"0,72–0,98 / ≤ 1,30",
		},
		{ "Plecak 100 (od 35.): poziomy dochodu", "11,4", fmtValue(v("gold.backpack_100.Warrior"), "1"), "3–8" },
		{ "Plecak 80 (od 25.): poziomy dochodu", "6,5", fmtValue(v("gold.backpack_80.Warrior"), "1"), "3–8" },
		{ "+1…+3 broni / dochód poziomu (21–45)", "0,44–0,69", range("R.duskwood.gold.up3", "2"), "≤ 1,05" },
		{
			"D5 (K0): Unikaty dla klasy na h expienia",
			"2,3–4,5",
			`{fmtValue(uniqueLo, "2")}–{fmtValue(uniqueHi, "2")}`,
			"2–4",
		},
		{
			"Części: rodzaje z częścią / części w przepisach 20–45",
			"8/13 / 0/5",
			`{count("R.duskwood.parts.kind")} / {count("R.duskwood.parts.recipe")}`,
			"13/13 / 5/5",
		},
	}
	tableOut({ "liczba", "start S92", "teraz", "cel" }, rows)
	-- the S92 targets without the guard and chain matrices (below)
	local listed: { B.TargetRow } = {}
	for _, row in s92Rows do
		if row.group ~= "guards" and not string.find(row.id, "gold.chain", 1, true) then
			table.insert(listed, row)
		end
	end
	local ok, all = countIn(s92Rows)
	add("### Cele S92 (`Balance.targetsS92`)")
	add()
	add(
		`{ok}/{all} w paśmie (z wierszami raportu). Strażniki T-SK i mikstury łańcuchowe w tabelach niżej; pozostałe wiersze regionu (Elity, Elity II, rodzaje, harmonogram, D5) w „Cele (20–45)”.`
	)
	add()
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(listed, "S92 (asertowane)"))
	-- guards matrix (G1)
	add("### Strażniki T-SK w paśmie (S92, G1)")
	add()
	add(
		"T-SK1 / T-SK2 względem własnego L20 (limity 1,15 / 1,25) i T-SK3 / areaCap (≤ 1) na 25 / 30 / 35 / 40 / 44 i na 45 (blok ścieżek S89–S90). Gwiazdka: wiersz w raporcie (na 45 build ma już wartość ponad limitem planu D1 albo powód w `Balance.S92_REPORT`)."
	)
	add()
	local gRows: { { string } } = {}
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			local cells = { `{c} {build.key}` }
			for _, L in { 25, 30, 35, 40, 44, 45 } do
				local g = SkillModel.guards(build, L)
				local mark = ""
				local id = `R.duskwood.guard.tsk1.{c}.{build.key}.{L}`
				if byId[id] and byId[id].report then
					mark = "*"
				end
				table.insert(
					cells,
					`{fmtValue(g.tsk1rel, "2")} / {fmtValue(g.tsk2rel, "2")} / {fmtValue(g.tsk3cap, "2")}{mark}`
				)
			end
			table.insert(gRows, cells)
		end
	end
	tableOut({ "build", "25", "30", "35", "40", "44", "45" }, gRows)
	-- T-SK3 / T-SK4 of the bases (report)
	local baseRows: { { string } } = {}
	for _, c in B.CLASSES do
		local build = SkillModel.build("base", c)
		local cells = { `{c} base: T-SK3{if c == "Mage" then " / T-SK4" else ""}` }
		for _, L in { 25, 30, 35, 40, 44 } do
			local m = SkillModel.metrics(build, L)
			table.insert(
				cells,
				if c == "Mage" then `{fmtValue(m.tsk3, "2")} / {fmtValue(m.tsk4, "2")}` else fmtValue(m.tsk3, "2")
			)
		end
		table.insert(baseRows, cells)
	end
	add("### Podstawy klas: T-SK3 i T-SK4 Maga (tylko raport, S92)")
	add()
	add("T-SK3 bazy (Mag z projektu 2,1–2,4, S90 I3) i T-SK4 bazy Maga (ROZWOJ 8: ok. 1,1–1,4) w paśmie 25–44.")
	add()
	tableOut({ "podstawa", "25", "30", "35", "40", "44" }, baseRows)
	-- pace (B1, F)
	add("### Tempo 19 → 45 (model okna S91, Wojownik; S92)")
	add()
	add(
		"h = godziny na poziom (rodzaj zwykły, odpoczynek, zadania główne bez bossów w oknach, poboczne 0,5); m = średnia krocząca h(L − 4..L) (raport); „rodzaj regionu” = `kindAtRegion` (opcja `region`, raport); „z Morvane” = zadanie z bossem w oknie (raport)."
	)
	add()
	local pRows: { { string } } = {}
	for L = 19, 45 do
		local h = B.paceWindowAt("Warrior", L).hours
		local prev = B.paceWindowAt("Warrior", L - 1).hours
		table.insert(pRows, {
			tostring(L),
			fmtValue(h, "2"),
			fmtValue(h / math.max(1e-9, prev), "2"),
			fmtValue(B.paceWindowMean("Warrior", L), "2"),
			fmtValue(B.paceWindowAt("Warrior", L, { kind = "region" }).hours, "2"),
			fmtValue(B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours, "2"),
		})
	end
	tableOut({ "poziom", "h", "h / h(L − 1)", "m", "h rodzaj regionu", "h z Morvane" }, pRows)
	local regionSum, bossSum = 0, 0
	for L = 20, 44 do
		regionSum += B.paceWindowAt("Warrior", L, { kind = "region" }).hours
		bossSum += B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours
	end
	add(
		`Suma 20 → 45: {fmtValue(pace, "2")} h (rodzaj regionu {fmtValue(regionSum, "2")} h, z Morvane {fmtValue(
			bossSum,
			"2"
		)} h); h(45) / h(44) = {fmtValue(B.paceWindowAt("Warrior", 45).hours / math.max(1e-9, h44), "2")} (rodzaje Pustkowi: S93).`
	)
	add()
	-- class premium (ROZWOJ 7.4)
	local premium: { { string } } = {}
	for _, L in { 30, 40 } do
		for _, party in { { "Warrior", "Warrior", "Warrior" }, { "Warrior", "Hunter", "Mage" } } do
			local p = B.paceAt("Warrior", L, { party = party })
			table.insert(premium, {
				`{L}: {table.concat(party, " + ")}`,
				fmtValue(p.expMul, "2"),
				fmtValue(p.expPerHour, "g"),
			})
		end
	end
	add("### Premia za różne klasy (tylko raport, S92)")
	add()
	tableOut({ "drużyna 3 osób", "mnożnik EXP", "EXP/h członka" }, premium)
	-- chain potions (I3)
	add("### Mikstury łańcuchowe ÷ dochód (S92, I3; dolna granica 15% tylko raport)")
	add()
	local chain: { { string } } = {}
	for L = 21, 45, 2 do
		local cells = { tostring(L) }
		for _, c in B.CLASSES do
			table.insert(cells, fmtValue(B.economyAt(c, L, { potions = "chain" }).potionShare, "%"))
		end
		table.insert(chain, cells)
	end
	tableOut({ "poziom", "Wojownik", "Łowca", "Mag", "Kapłan" }, chain)
	-- D5 with luck (H3)
	add("### D5 ze szczęściem (tylko raport, S92)")
	add()
	add(
		"Unikaty dla klasy na h expienia / Heroiki na h Elit: K0, K1, K1 z Kapłanem Fortuny, K2 z Kapłanem Fortuny (profile S84 / S88)."
	)
	add()
	local d5: { { string } } = {}
	for _, L in { 25, 30, 35, 40 } do
		for _, c in { "Warrior", "Cleric" } do
			local cells = { `{c} {L}` }
			for _, spec in { { "K0", false }, { "K1", false }, { "K1", "full" }, { "K2", "full" } } do
				local d = B.dropsPerHour(c, L, spec[1] :: string, spec[2] :: any)
				table.insert(cells, `{fmtValue(d.unique, "2")} / {fmtValue(d.heroic, "2")}`)
			end
			table.insert(d5, cells)
		end
	end
	tableOut({ "klasa · poziom", "K0", "K1", "K1 + Fortuna", "K2 + Fortuna" }, d5)
	-- casters and Elite pairs (report)
	add("### Rodzaje rzucające i pary Elit (tylko raport, S92)")
	add()
	local kRows: { { string } } = {}
	for _, k in B.kindRates("duskwood") do
		if k.caster then
			table.insert(
				kRows,
				{ k.kind, tostring(k.level), fmtValue(k.hpPerExp, "2"), fmtValue(k.hpPerExpGeneric, "2") }
			)
		end
	end
	tableOut(
		{ "rodzaj rzucający", "poziom", "HP/EXP ÷ średnia regionu", "HP/EXP ÷ zwykły (szkic S54: 1,20)" },
		kRows
	)
	local pairRows: { { string } } = {}
	for _, cave in B.caveElites("duskwood") do
		for _, kind in cave.kinds do
			local worst = 0
			for _, f in kind.fights do
				worst = math.max(worst, f.pair.hpLost / math.max(1e-9, f.single.hpLost))
			end
			table.insert(pairRows, { `{cave.id} {kind.kind}`, fmtValue(cave.pairShare, "%"), fmtValue(worst, "2") })
		end
	end
	tableOut({ "jaskinia · rodzaj", "q par", "para ÷ pojedyncza (najwięcej; cel ≤ 2,6)" }, pairRows)
	-- Morvane extras (C)
	add("### Morvane: tylko raport (S92)")
	add()
	local mRows: { { string } } = {}
	for n = 3, 5 do
		local r = B.bossNoSupport("morvane", n)
		local pots = {}
		for _, mem in r.members do
			table.insert(pots, `{mem.key} {fmtValue(mem.potions, "1")}`)
		end
		table.insert(mRows, { `bez wsparcia, {n} graczy: mikstury na walkę`, table.concat(pots, ", ") })
	end
	local def = Bosses.byId.morvane :: any
	local m = B.monster(B.bossKind(def, 4), def.level, "boss")
	for _, key in { "trapper.poisoner", "inquisitor.solo" } do
		local sp = SkillModel.player(SkillModel.build(key), 44)
		local d60 = SkillModel.fight(sp, { targets = { m }, seconds = 60 }).dps
		local d300 = SkillModel.fight(sp, { targets = { m }, seconds = 300 }).dps
		table.insert(mRows, {
			`{key} na Morvane: DPS 300 s ÷ DPS 60 s`,
			`{fmtValue(d300 / math.max(1e-9, d60), "2")} ({fmtValue(d60, "g")} → {fmtValue(d300, "g")})`,
		})
	end
	local waves = {}
	for n = 3, 5 do
		local ws = B.shieldWaves("morvane", B.team(n, S.bossLevel))
		table.insert(waves, `{n}: {fmtValue(ws[1].seconds, "1")} / {fmtValue(ws[2].seconds, "1")} s`)
	end
	table.insert(mRows, { "fale tarczy: czas fali 2 / 3 (drużyna S32)", table.concat(waves, ", ") })
	tableOut({ "liczba", "wartość" }, mRows)
	-- R4 in the band (G3)
	add("### Przełomy A / B osiągane w 21–45 (tylko raport, S92, G3)")
	add()
	add(
		"R4 = zysk opcji w roli umiejętności na poziomie rangi (S89 E1, `SkillModel.optionGain`); pasmo 0,08–0,17 (5) i 0,17–0,28 (10); opcje użytkowe (`R4_UTILITY`) bez liczby. Blok ścieżek asertuje te same opcje na 45 / 70 / 100."
	)
	add()
	local r4Rows: { { string } } = {}
	for _, classId in B.CLASSES do
		for _, d in SkillData.byClass[classId] do
			local def2: any = d
			if def2.type == "passive" or not def2.breakpoints then
				continue
			end
			local key = SkillModel.R4_SUPPORT_BUILDS[def2.id]
				or (if def2.path then SkillModel.R4_PATH_BUILDS[def2.path] else SkillModel.R4_CLASS_BUILDS[classId])
			local build = SkillModel.build(key)
			for _, at in Skills.BREAKPOINT_LEVELS do
				local rankLevel = Skills.rankLevel(def2, at)
				if rankLevel > 20 and rankLevel <= 45 and def2.breakpoints[at] then
					local L = math.max(rankLevel, 21)
					local cells = { `{def2.id} {at} ({key})`, tostring(L) }
					for _, choice in { "a", "b" } do
						local k = `{def2.id}:{at}{choice}`
						if SkillModel.R4_UTILITY[k] then
							table.insert(cells, "użyteczność")
						else
							local g = SkillModel.optionGain(build, def2.id, at, choice, L)
							table.insert(cells, if g then fmtValue(g, "2") else "–")
						end
					end
					table.insert(r4Rows, cells)
				end
			end
		end
	end
	tableOut({ "umiejętność · przełom (build)", "poziom", "A", "B" }, r4Rows)
	-- anchors 45 -> 46-69 (S93)
	add("### Kotwice 45 a poziomy 46–69 (S92 → S93)")
	add()
	add(
		"S92 nie przestawiło żadnej kotwicy 45 (`monsterHp`, `monsterAtk`, `eliteHp`, `eliteDmg`, `elite2*`, `expToNext`, `manaCost.Mage`, `heal`): węzły dodało tylko w 21–44 (`manaCost.Mage` 25 / 30 / 40, `heal` 25), więc krzywe na 46–69 są jak po S87. Na 46–69 przechodzą: Morvane (sytuacja boss S84 na 45+ to Azgor), zakresy rodzajów Boru do 45 i `rewardMul` (rodzaje Pustkowi bez zmian). Wartości kotwic 45:"
	)
	add()
	local aRows: { { string } } = {}
	for _, id in LevelCurves.ids() do
		table.insert(aRows, { id, fmtValue(LevelCurves.at(id, 45), "2"), fmtValue(LevelCurves.at(id, 55), "2") })
	end
	tableOut({ "krzywa", "45", "55" }, aRows)
end

-- S93 (L1): the Scorched Wastes section: start S93 -> now, the S93 targets (Balance.targetsS93) and the "Tylko
-- raport" items of the session file.
local function s93Section()
	local S = B.S93
	local s93Rows = B.targetsS93()
	local byId: { [string]: B.TargetRow } = {}
	for _, row in s93Rows do
		byId[row.id] = row
	end
	local function v(id: string): number
		local row = byId[`R.ashen.{id}`]
		return if row then row.value else 0 / 0
	end
	local function range(prefix: string, fmt: string): string
		local lo, hi = math.huge, -math.huge
		for _, row in s93Rows do
			if string.sub(row.id, 1, #prefix) == prefix then
				lo, hi = math.min(lo, row.value), math.max(hi, row.value)
			end
		end
		if lo == math.huge then
			return "–"
		end
		return `{fmtValue(lo, fmt)}–{fmtValue(hi, fmt)}`
	end
	local function count(prefix: string): string
		local ok, all = 0, 0
		for _, row in s93Rows do
			if string.sub(row.id, 1, #prefix) == prefix then
				all += 1
				ok += if B.inBand(row) then 1 else 0
			end
		end
		return `{ok}/{all}`
	end
	local function three(prefix: string, suffix: string, fmt: string): string
		local out = {}
		for n = 3, 5 do
			table.insert(out, fmtValue(v(`{prefix}{n}{suffix}`), fmt))
		end
		return table.concat(out, " / ")
	end
	local regionRows = B.targetsRegion("ashen")
	local function regionRange(group: string, needle: string?, fmt: string): string
		local lo, hi = math.huge, -math.huge
		for _, row in regionRows do
			if row.group == group and (needle == nil or string.find(row.id, needle, 1, true)) then
				lo, hi = math.min(lo, row.value), math.max(hi, row.value)
			end
		end
		return `{fmtValue(lo, fmt)}–{fmtValue(hi, fmt)}`
	end
	local function regionMax(group: string, classId: string?, needle: string?): number
		local hi = -math.huge
		for _, row in regionRows do
			if
				row.group == group
				and (classId == nil or row.classId == classId)
				and (needle == nil or string.find(row.id, needle, 1, true) ~= nil)
			then
				hi = math.max(hi, row.value)
			end
		end
		return hi
	end
	local function regionMin(group: string): number
		local lo = math.huge
		for _, row in regionRows do
			if row.group == group then
				lo = math.min(lo, row.value)
			end
		end
		return lo
	end
	add("### S93: Spalone Pustkowia i Azgor (start S93 → teraz)")
	add()
	add(
		"Start = stan po S92 (`15def98`), zmierzony tym samym modelem przed zmianą danych. Cele: `docs/sessions/S93.md` → „Cele tej sesji”; wiersze asertuje blok regionów `balance.spec` (`TUNED.ashen`, `Balance.targetsS93`), wiersze z opisem w kolumnie „kto asertuje” są w raporcie (powody: `docs/DECYZJE.md` → S93)."
	)
	add()
	local pace, h69, step = 0, B.paceWindowAt("Warrior", 69).hours, 0
	for L = 45, 69 do
		pace += B.paceWindowAt("Warrior", L).hours
		step =
			math.max(step, B.paceWindowAt("Warrior", L).hours / math.max(1e-9, B.paceWindowAt("Warrior", L - 1).hours))
	end
	local rows = {
		{ "Azgor 3 / 4 / 5 graczy L69: min", "5,14 / 5,30 / 5,13", three("azgor.team", "", "2"), "4–6" },
		{ "Azgor z węzłami 3 / 4 / 5: min", "4,62 / 4,77 / 4,71", three("azgor.team", "@nodes", "2"), "4–6" },
		{
			"Azgor: największy cios Maga L70 / L68 (inferno)",
			"118% / 122%",
			`{fmtValue(v("azgor.mage70"), "%")} / {fmtValue(v("azgor.mage68"), "%")}`,
			"≤ 70% / < 100%",
		},
		{ "Azgor: zwykły cios Maga L70", "35%", fmtValue(v("azgor.basic70"), "%"), "7–12%" },
		{ "Azgor: tank HP na minutę (model S32)", "816%", fmtValue(v("azgor.tank"), "%"), "≤ 350%" },
		{
			"Azgor: tank HP na minutę (bossFight; 3 / 4 / 5)",
			"649% / 665% / 678%",
			three("azgor.tankFight", "", "%"),
			"raport",
		},
		{ "Azgor: meteor na minutę / HP Maga L70", "215%", fmtValue(v("azgor.meteor"), "%"), "≤ 60%" },
		{ "Azgor: tick lawy / HP Maga L70", "23% (6% po cięciu atkMul)", fmtValue(v("azgor.lava"), "%"), "15–25%" },
		{
			"Azgor: fala tarczy, HP na członka (3 / 4 / 5)",
			"275% / 183% / 179%",
			three("azgor.wave", "", "%"),
			"≤ 110%",
		},
		{
			"Azgor: G11 (najmniejsze tempo ataku; inferno w fazie 3)",
			"53% (inferno 68%)",
			fmtValue(regionMin("bossCadence"), "%"),
			"≥ 50%",
		},
		{
			"Azgor: T-SK6 Uzdrowiciela lochowego",
			"5,23",
			fmtValue(v("azgor.tsk6"), "2"),
			`1,0–{fmtValue(S.tsk6[2], "2")}`,
		},
		{ "Azgor bez wsparcia 3 / 4 / 5: s", "108 / 107 / 101", three("azgor.noSupport.", ".seconds", "1"), "≤ 480" },
		{
			"Azgor bez wsparcia: przyjmowane / podtrzymanie (najgorszy, 3 / 4 / 5)",
			"0,79 / 0,81 / 0,83",
			three("azgor.noSupport.", ".sustain", "2"),
			"≤ 1,0",
		},
		{
			"Azgor bez wsparcia: największy cios / HP członka",
			"111%",
			fmtValue(v("azgor.noSupport.3.hit"), "%"),
			"≤ 100%",
		},
		{
			"Elity: spotkanie Wojownik / Mag (najgorsze)",
			"158% / 163%",
			`{fmtValue(regionMax("eliteEncounter", "Warrior"), "%")} / {fmtValue(
				regionMax("eliteEncounter", "Mage"),
				"%"
			)}`,
			"≤ 110% / ≤ 125%",
		},
		{
			"Elita II solo / 2 / 3 graczy",
			"2,55–3,45 / 1,11–1,42 / 0,74–0,95",
			`{regionRange("elite2", ".solo", "2")} / {regionRange("elite2", ".duo", "2")} / {regionRange(
				"elite2",
				".trio",
				"2"
			)}`,
			"≥ 1,8 / ≤ 1,5 / 0,6–1,0",
		},
		{ "Elity dropią ilvl 46–70", "22/25", count("R.ashen.ilvl.elite"), "każdy" },
		{ "Expowiska na 68 / 69", "1 / 1", `{v("areas.68")} / {v("areas.69")}`, "≥ 2" },
		{
			"Rodzaje: EXP/s ÷ zwykły (najmniej)",
			"0,69 (magmaGolem)",
			fmtValue(regionMin("kinds"), "2"),
			"0,85–1,20",
		},
		{
			"Ognisty Chochlik: HP/EXP ÷ średnia regionu",
			"1,14",
			fmtValue(regionMax("kinds", nil, ".casterHp"), "2"),
			"≤ 1,25",
		},
		{ "Tempo 45 → 70 (okno): h", "26,14", fmtValue(pace, "2"), "21,25–28,75" },
		{
			"Tempo: h(69) / największy krok h(L) / h(L − 1)",
			"1,23 / 1,07 (L55)",
			`{fmtValue(h69, "2")} / {fmtValue(step, "2")}`,
			"0,98–1,32 / ≤ 1,30",
		},
		{ "Plecak 130 (od 50.): poziomy dochodu", "13,2", fmtValue(v("gold.backpack_130.Warrior"), "1"), "3–8" },
		{ "+1…+3 broni / dochód poziomu (46–69)", "0,56–0,74", range("R.ashen.gold.up3", "2"), "≤ 1,05" },
		{
			"Mikstury łańcuchowe / dochód (46–69)",
			"0,36–1,00",
			range("R.ashen.gold.chain.", "2"),
			"0,15–0,30 (górna: raport)",
		},
		{ "D5 (K0): Unikaty dla klasy na h expienia", "2,90–4,17", regionRange("d5", ".unique", "2"), "2–4" },
		{
			"Części: rodzaje z częścią / części w przepisach 45–70 / eliksir ognia",
			"8/13 / 0/6 / 30",
			`{count("R.ashen.parts.kind")} / {count("R.ashen.parts.recipe")} / {fmtValue(v("parts.elixirFire"), "0")}`,
			"13/13 / 6/6 / 45",
		},
		{ "`support.elites` na 55 / 65", "0/10", count("R.ashen.support"), "10/10 (raport)" },
	}
	tableOut({ "liczba", "start S93", "teraz", "cel" }, rows)
	local listed: { B.TargetRow } = {}
	for _, row in s93Rows do
		if row.group ~= "guards" and not string.find(row.id, "gold.", 1, true) and row.group ~= "pace" then
			table.insert(listed, row)
		end
	end
	local ok, all = countIn(s93Rows)
	add("### Cele S93 (`Balance.targetsS93`)")
	add()
	add(
		`{ok}/{all} w paśmie (z wierszami raportu). Strażniki T-SK, złoto i tempo w tabelach niżej; pozostałe wiersze regionu (Elity, Elity II, rodzaje, harmonogram, D5) w „Cele (45–70)”.`
	)
	add()
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(listed, "S93 (asertowane)"))
	-- guards matrix (G1)
	add("### Strażniki T-SK w paśmie (S93, G1)")
	add()
	add(
		"T-SK1 / T-SK2 względem własnego L20 (limity 1,15 / 1,25) i T-SK3 / areaCap (≤ 1) na 50 / 55 / 60 / 65 / 69 / 70 (rzędy 7–9 według punktów). Gwiazdka: wiersz w raporcie (na 45 build ma już wartość ponad limitem planu D1, reguła S92, albo powód grupy w `Balance.S93_REPORT`); T-SK4 Maga i T-SK5 Uzdrowiciela lochowego w „Cele S93”."
	)
	add()
	local gRows: { { string } } = {}
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			local cells = { `{c} {build.key}` }
			for _, L in S.guardLevels do
				local g = SkillModel.guards(build, L)
				local mark = ""
				for _, metric in { "tsk1", "tsk2", "tsk3" } do
					local row = byId[`R.ashen.guard.{metric}.{c}.{build.key}.{L}`]
					if row and row.report and not B.inBand(row) then
						mark = "*"
					end
				end
				table.insert(
					cells,
					`{fmtValue(g.tsk1rel, "2")} / {fmtValue(g.tsk2rel, "2")} / {fmtValue(g.tsk3cap, "2")}{mark}`
				)
			end
			table.insert(gRows, cells)
		end
	end
	tableOut({ "build", "50", "55", "60", "65", "69", "70" }, gRows)
	local baseRows: { { string } } = {}
	for _, c in B.CLASSES do
		local build = SkillModel.build("base", c)
		local cells = { `{c} base: T-SK3{if c == "Mage" then " / T-SK4" else ""}` }
		for _, L in S.guardLevels do
			local m = SkillModel.metrics(build, L)
			table.insert(
				cells,
				if c == "Mage" then `{fmtValue(m.tsk3, "2")} / {fmtValue(m.tsk4, "2")}` else fmtValue(m.tsk3, "2")
			)
		end
		table.insert(baseRows, cells)
	end
	add("### Podstawy klas: T-SK3 i T-SK4 Maga (tylko raport, S93)")
	add()
	tableOut({ "podstawa", "50", "55", "60", "65", "69", "70" }, baseRows)
	-- Fortune vs the dungeon Healer (ROZWOJ 9.6)
	local fRows: { { string } } = {}
	for _, L in S.guardLevels do
		local healer = SkillModel.oneHeal(SkillModel.build("healer.dungeon", "Cleric"), L, SkillModel.defenderTank(L))
		local fortune = SkillModel.oneHeal(SkillModel.build("fortune.plunder", "Cleric"), L, SkillModel.defenderTank(L))
		table.insert(fRows, {
			tostring(L),
			fmtValue(healer, "2"),
			fmtValue(fortune, "2"),
			fmtValue(1 - fortune / math.max(1e-9, healer), "%"),
		})
	end
	add("### Leczenie Fortuny wobec „Lochowego” (tylko raport, S93; ROZWOJ 9.6: ok. 21% słabiej)")
	add()
	tableOut({ "poziom", "T-SK5 Uzdrowiciel lochowy", "T-SK5 Fortuna łupieżcza", "słabiej o" }, fRows)
	-- pace (F)
	add("### Tempo 44 → 70 (model okna S91, Wojownik; S93)")
	add()
	add(
		"h = godziny na poziom (rodzaj zwykły, odpoczynek, zadania główne bez bossów w oknach, poboczne 0,5); m = średnia krocząca h(L − 4..L) (raport); „rodzaj regionu” = `kindAtRegion` (opcja `region`, raport); „z Azgorem” = zadanie z bossem w oknie (raport). Okno zadania `deepforge` sięga 71. (do `frostpeak`), więc część jego EXP liczy się w paśmie S94."
	)
	add()
	local pRows: { { string } } = {}
	for L = 44, 70 do
		local h = B.paceWindowAt("Warrior", L).hours
		local prev = B.paceWindowAt("Warrior", L - 1).hours
		table.insert(pRows, {
			tostring(L),
			fmtValue(h, "2"),
			fmtValue(h / math.max(1e-9, prev), "2"),
			fmtValue(B.paceWindowMean("Warrior", L), "2"),
			fmtValue(B.paceWindowAt("Warrior", L, { kind = "region" }).hours, "2"),
			fmtValue(B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours, "2"),
		})
	end
	tableOut({ "poziom", "h", "h / h(L − 1)", "m", "h rodzaj regionu", "h z Azgorem" }, pRows)
	local regionSum, bossSum = 0, 0
	for L = 45, 69 do
		regionSum += B.paceWindowAt("Warrior", L, { kind = "region" }).hours
		bossSum += B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours
	end
	add(
		`Suma 45 → 70: {fmtValue(pace, "2")} h (rodzaj regionu {fmtValue(regionSum, "2")} h, z Azgorem {fmtValue(
			bossSum,
			"2"
		)} h); h(70) / h(69) = {fmtValue(B.paceWindowAt("Warrior", 70).hours / math.max(1e-9, h69), "2")} (stosunki 70–99: S94).`
	)
	add()
	-- class premium (ROZWOJ 7.4)
	local premium: { { string } } = {}
	for _, L in { 55, 65 } do
		for _, party in { { "Warrior", "Warrior", "Warrior" }, { "Warrior", "Hunter", "Mage" } } do
			local p = B.paceAt("Warrior", L, { party = party })
			table.insert(premium, {
				`{L}: {table.concat(party, " + ")}`,
				fmtValue(p.expMul, "2"),
				fmtValue(p.expPerHour, "g"),
			})
		end
	end
	add("### Premia za różne klasy (tylko raport, S93)")
	add()
	tableOut({ "drużyna 3 osób", "mnożnik EXP", "EXP/h członka" }, premium)
	-- chain potions (I2)
	add("### Mikstury łańcuchowe ÷ dochód (S93, I2; górna granica 30% w raporcie, dolna 15% asertowana)")
	add()
	local chain: { { string } } = {}
	for L = 46, 69, 2 do
		local cells = { tostring(L) }
		for _, c in B.CLASSES do
			table.insert(cells, fmtValue(B.economyAt(c, L, { potions = "chain" }).potionShare, "%"))
		end
		table.insert(chain, cells)
	end
	tableOut({ "poziom", "Wojownik", "Łowca", "Mag", "Kapłan" }, chain)
	-- protected +9 (B3, I4)
	add("### Rdzenie Legendy i zwoje ochrony (tylko raport, S93, I4)")
	add()
	add(
		"Chroniony +9 Legendarnej broni Wojownika (`Balance.protectedFlow`): złoto ulepszeń, zwoje ochrony (alchemik 2000 zł; drop: Elita II 0,08, Azgor 0,35) i Rdzenie Legendy (od +8, S87; Azgor 0,2), w poziomach dochodu Wojownika na tym poziomie. Cel kompletu +9 z ochroną (150–300 h) jest S94."
	)
	add()
	local flowRows: { { string } } = {}
	for _, ilvl in { 50, 60, 70 } do
		local f = B.protectedFlow(ilvl)
		table.insert(flowRows, {
			tostring(ilvl),
			fmtValue(f.gold, "0"),
			fmtValue(f.scrolls, "1"),
			fmtValue(f.cores, "1"),
			fmtValue(f.scrollGold, "0"),
			fmtValue(f.levels, "1"),
		})
	end
	tableOut({ "ilvl", "złoto ulepszeń", "zwoje", "Rdzenie Legendy", "złoto zwojów", "poziomy dochodu" }, flowRows)
	-- D5 with luck (H3)
	add("### D5 ze szczęściem (tylko raport, S93)")
	add()
	add(
		"Unikaty dla klasy na h expienia / Heroiki na h Elit: K0, K1, K1 z Kapłanem Fortuny, K2 z Kapłanem Fortuny (profile S84 / S88; limit szczęścia `monsterItemCap`)."
	)
	add()
	local d5: { { string } } = {}
	for _, L in { 50, 55, 60, 65, 69 } do
		for _, c in { "Warrior", "Cleric" } do
			local cells = { `{c} {L}` }
			for _, spec in { { "K0", false }, { "K1", false }, { "K1", "full" }, { "K2", "full" } } do
				local d = B.dropsPerHour(c, L, spec[1] :: string, spec[2] :: any)
				table.insert(cells, `{fmtValue(d.unique, "2")} / {fmtValue(d.heroic, "2")}`)
			end
			table.insert(d5, cells)
		end
	end
	tableOut({ "klasa · poziom", "K0", "K1", "K1 + Fortuna", "K2 + Fortuna" }, d5)
	-- casters and Elite pairs (report)
	add("### Rodzaje rzucające i pary Elit (tylko raport, S93)")
	add()
	local kRows: { { string } } = {}
	for _, k in B.kindRates("ashen") do
		if k.caster then
			table.insert(
				kRows,
				{ k.kind, tostring(k.level), fmtValue(k.hpPerExp, "2"), fmtValue(k.hpPerExpGeneric, "2") }
			)
		end
	end
	tableOut(
		{ "rodzaj rzucający", "poziom", "HP/EXP ÷ średnia regionu", "HP/EXP ÷ zwykły (szkic S55: 1,20)" },
		kRows
	)
	local pairRows: { { string } } = {}
	for _, cave in B.caveElites("ashen") do
		for _, kind in cave.kinds do
			local worst = 0
			for _, f in kind.fights do
				worst = math.max(worst, f.pair.hpLost / math.max(1e-9, f.single.hpLost))
			end
			table.insert(pairRows, { `{cave.id} {kind.kind}`, fmtValue(cave.pairShare, "%"), fmtValue(worst, "2") })
		end
	end
	tableOut({ "jaskinia · rodzaj", "q par", "para ÷ pojedyncza (najwięcej; cel ≤ 2,6)" }, pairRows)
	-- Azgor extras (C)
	add("### Azgor: tylko raport (S93)")
	add()
	local def = Bosses.byId.azgor :: any
	local aRows: { { string } } = {}
	for n = 3, 5 do
		local r = B.bossNoSupport("azgor", n)
		local pots = {}
		for _, mem in r.members do
			table.insert(pots, `{mem.key} {fmtValue(mem.potions, "1")}`)
		end
		table.insert(aRows, { `bez wsparcia, {n} graczy: mikstury na walkę`, table.concat(pots, ", ") })
	end
	do
		local team = B.team(5, S.bossLevel)
		team[2] = B.player("Mage", 70)
		local share1 = B.bossFight("azgor", team, { hazardShare = 1 })
		local share0 = B.bossFight("azgor", team)
		table.insert(aRows, {
			"lawa przy hazardShare = 1: tank HP na minutę w fazie 3 (z lawą / bez)",
			`{fmtValue(share1.phases[3].tankDps * 60 / team[1].values.maxHp, "%")} / {fmtValue(
				share0.phases[3].tankDps * 60 / team[1].values.maxHp,
				"%"
			)}`,
		})
		local consts = B.bossScriptConsts("azgor")
		local inferno = 0
		for _, at in def.attacks do
			if at.id == "inferno" then
				inferno = at.radius
			end
		end
		local safe = consts.SAFE_START or 0
		local shrink = (safe - (consts.SAFE_END or 0)) / math.max(1e-9, consts.SHRINK_SECONDS or 1)
		local seconds = math.max(0, (safe - inferno) / math.max(1e-9, shrink))
		table.insert(aRows, {
			"faza 3: sekundy, przez które bezpieczny krąg mieści walczących z dystansu poza inferno (promień ≥ zasięg inferno)",
			`{fmtValue(seconds, "0")} s z {fmtValue(share0.phases[3].seconds, "0")} s fazy 3 (5 graczy)`,
		})
	end
	local m = B.monster(B.bossKind(def, 4), def.level, "boss")
	for _, key in { "trapper.poisoner", "inquisitor.solo" } do
		local sp = SkillModel.player(SkillModel.build(key), S.bossLevel)
		local d60 = SkillModel.fight(sp, { targets = { m }, seconds = 60 }).dps
		local d300 = SkillModel.fight(sp, { targets = { m }, seconds = 300 }).dps
		table.insert(aRows, {
			`{key} na Azgorze: DPS 300 s ÷ DPS 60 s`,
			`{fmtValue(d300 / math.max(1e-9, d60), "2")} ({fmtValue(d60, "g")} → {fmtValue(d300, "g")})`,
		})
	end
	local waves = {}
	for n = 3, 5 do
		local ws = B.shieldWaves("azgor", B.team(n, S.bossLevel))
		table.insert(waves, `{n}: {fmtValue(ws[1].seconds, "1")} / {fmtValue(ws[2].seconds, "1")} s`)
	end
	table.insert(aRows, { "fale tarczy: czas fali 2 / 3 (drużyna S32)", table.concat(waves, ", ") })
	for phase = 1, 3 do
		local cad = B.bossCadence(def, phase)
		local parts = {}
		for _, at in def.attacks do
			if cad.perMinute[at.id] then
				table.insert(
					parts,
					`{at.id} {fmtValue(cad.perMinute[at.id], "1")}/min ({fmtValue(cad.rateShare[at.id], "%")})`
				)
			end
		end
		table.insert(aRows, { `harmonogram fazy {phase}`, table.concat(parts, ", ") })
	end
	tableOut({ "liczba", "wartość" }, aRows)
	-- R4 in the band (G3, G4)
	add("### Przełomy A / B osiągane w 46–70 (tylko raport, S93, G3)")
	add()
	add(
		"R4 = zysk opcji w roli umiejętności na poziomie rangi (S89 E1, `SkillModel.optionGain`); pasmo 0,08–0,17 (5) i 0,17–0,28 (10); opcje użytkowe (`R4_UTILITY`) bez liczby. Blok ścieżek asertuje te same opcje na 45 / 70 / 100. Rozpłatanie 10A (G4) w buildzie „Furia” z węzłem „Rozdzierające Cięcia” i bez niego pod tabelą."
	)
	add()
	local r4Rows: { { string } } = {}
	for _, classId in B.CLASSES do
		for _, d in SkillData.byClass[classId] do
			local def2: any = d
			if def2.type == "passive" or not def2.breakpoints then
				continue
			end
			local key = SkillModel.R4_SUPPORT_BUILDS[def2.id]
				or (if def2.path then SkillModel.R4_PATH_BUILDS[def2.path] else SkillModel.R4_CLASS_BUILDS[classId])
			local build = SkillModel.build(key)
			for _, at in Skills.BREAKPOINT_LEVELS do
				local rankLevel = Skills.rankLevel(def2, at)
				if rankLevel > 45 and rankLevel <= 70 and def2.breakpoints[at] then
					local cells = { `{def2.id} {at} ({key})`, tostring(rankLevel) }
					for _, choice in { "a", "b" } do
						local k = `{def2.id}:{at}{choice}`
						if SkillModel.R4_UTILITY[k] then
							table.insert(cells, "użyteczność")
						else
							local g = SkillModel.optionGain(build, def2.id, at, choice, rankLevel)
							table.insert(cells, if g then fmtValue(g, "2") else "–")
						end
					end
					table.insert(r4Rows, cells)
				end
			end
		end
	end
	tableOut({ "umiejętność · przełom (build)", "poziom", "A", "B" }, r4Rows)
	do
		local fury = SkillModel.build("berserker.fury", "Warrior")
		local bare = SkillModel.withoutNodes(fury, { "berserker_rendingCuts" })
		local cells = {}
		for _, L in { 46, 55, 70 } do
			local a = SkillModel.optionGain(fury, "cleave", 10, "a", L)
			local b = SkillModel.optionGain(bare, "cleave", 10, "a", L)
			table.insert(
				cells,
				`{L}: {if a then fmtValue(a, "2") else "–"} / {if b then fmtValue(b, "2") else "–"}`
			)
		end
		add(
			`Rozpłatanie 10A (3 stosy krwawienia) w „Furii” z węzłem / bez węzła „Rozdzierające Cięcia”: {table.concat(
				cells,
				"; "
			)}. 10B (kradzież życia) to opcja użytkowa (\`R4_UTILITY\`).`
		)
		add()
	end
	-- anchors 70 -> 71-99 (S94)
	add("### Kotwice 70 a poziomy 71–99 (S93 → S94)")
	add()
	add(
		"S93 nie przestawiło żadnej kotwicy 70 (`monsterHp`, `monsterAtk`, `eliteHp`, `eliteDmg`, `elite2*`, `expToNext`, `manaCost.Mage`, `heal`): wiersze pasma mieszczą się w celach na krzywych S87 / S92, więc 71–99 zostają jak po S87. Na 71+ przechodzą: zakresy Kuźni do 70 (Elity ze spawnerów 69–70 mają poziom 71–72), `rewardMul` golemów, Azgor (sytuacja boss S84 na 70+ to Vaelgrath). Wartości kotwic 70:"
	)
	add()
	local kRows2: { { string } } = {}
	for _, id in LevelCurves.ids() do
		table.insert(kRows2, { id, fmtValue(LevelCurves.at(id, 70), "2"), fmtValue(LevelCurves.at(id, 80), "2") })
	end
	tableOut({ "krzywa", "70", "80" }, kRows2)
end

-- S94 (M1): the Frost Peaks section: start S94 -> now, the S94 targets (Balance.targetsS94) and the "Tylko raport"
-- items of the session file.
local function s94Section()
	local S = B.S94
	local s94Rows = B.targetsS94()
	local byId: { [string]: B.TargetRow } = {}
	for _, row in s94Rows do
		byId[row.id] = row
	end
	local function v(id: string): number
		local row = byId[`R.frostpeak.{id}`]
		return if row then row.value else 0 / 0
	end
	local function range(prefix: string, fmt: string): string
		local lo, hi = math.huge, -math.huge
		for _, row in s94Rows do
			if string.sub(row.id, 1, #prefix) == prefix then
				lo, hi = math.min(lo, row.value), math.max(hi, row.value)
			end
		end
		if lo == math.huge then
			return "–"
		end
		return `{fmtValue(lo, fmt)}–{fmtValue(hi, fmt)}`
	end
	local function count(prefix: string): string
		local ok, all = 0, 0
		for _, row in s94Rows do
			if string.sub(row.id, 1, #prefix) == prefix then
				all += 1
				ok += if B.inBand(row) then 1 else 0
			end
		end
		return `{ok}/{all}`
	end
	local function three(prefix: string, suffix: string, fmt: string): string
		local out = {}
		for n = 3, 5 do
			table.insert(out, fmtValue(v(`{prefix}{n}{suffix}`), fmt))
		end
		return table.concat(out, " / ")
	end
	local regionRows = B.targetsRegion("frostpeak")
	local function regionRange(group: string, needle: string?, fmt: string): string
		local lo, hi = math.huge, -math.huge
		for _, row in regionRows do
			if row.group == group and (needle == nil or string.find(row.id, needle, 1, true)) then
				lo, hi = math.min(lo, row.value), math.max(hi, row.value)
			end
		end
		return `{fmtValue(lo, fmt)}–{fmtValue(hi, fmt)}`
	end
	local function regionMax(group: string, classId: string?, needle: string?): number
		local hi = -math.huge
		for _, row in regionRows do
			if
				row.group == group
				and (classId == nil or row.classId == classId)
				and (needle == nil or string.find(row.id, needle, 1, true) ~= nil)
			then
				hi = math.max(hi, row.value)
			end
		end
		return hi
	end
	local function regionMin(group: string, needle: string?): number
		local lo = math.huge
		for _, row in regionRows do
			if row.group == group and (needle == nil or string.find(row.id, needle, 1, true) ~= nil) then
				lo = math.min(lo, row.value)
			end
		end
		return lo
	end
	local function share(group: string): number
		for _, row in regionRows do
			if row.group == group and string.find(row.id, ".share", 1, true) then
				return row.value
			end
		end
		return 0 / 0
	end
	add("### S94: Lodowe Szczyty i Vaelgrath (start S94 → teraz)")
	add()
	add(
		"Start = stan po S93 (`ef4fb39`), zmierzony tym samym modelem przed zmianą danych (start tempa przed poprawką okna ostatniego zadania głównego, DECYZJE S94). Cele: `docs/sessions/S94.md` → „Cele tej sesji”; wiersze asertuje blok regionów `balance.spec` (`Balance.targetsS94`, bez bramki `TUNED`), wiersze z opisem w kolumnie „kto asertuje” są w raporcie (powody: `docs/DECYZJE.md` → S94)."
	)
	add()
	local pace, step = 0, 0
	for L = 70, 99 do
		pace += B.paceWindowAt("Warrior", L).hours
		step =
			math.max(step, B.paceWindowAt("Warrior", L).hours / math.max(1e-9, B.paceWindowAt("Warrior", L - 1).hours))
	end
	local rows = {
		{ "Vaelgrath 3 / 4 / 5 graczy L99: min", "4,58 / 4,82 / 4,67", three("vaelgrath.team", "", "2"), "4–6" },
		{
			"Vaelgrath z węzłami 3 / 4 / 5: min",
			"4,01 / 4,25 / 4,21",
			three("vaelgrath.team", "@nodes", "2"),
			"4–6",
		},
		{
			"Vaelgrath: największy cios Maga L100 / L98 (Lodowy Pierścień)",
			"130% / 132%",
			`{fmtValue(v("vaelgrath.mage100"), "%")} / {fmtValue(v("vaelgrath.mage98"), "%")}`,
			"≤ 70% / < 100%",
		},
		{ "Vaelgrath: zwykły cios Maga L100", "33%", fmtValue(v("vaelgrath.basic100"), "%"), "7–12%" },
		{ "Vaelgrath: tank HP na minutę (model S32)", "1063%", fmtValue(v("vaelgrath.tank"), "%"), "≤ 350%" },
		{
			"Vaelgrath: tank HP na minutę (bossFight; 3 / 4 / 5)",
			"849% / 865% / 880%",
			three("vaelgrath.tankFight", "", "%"),
			"raport",
		},
		{ "Vaelgrath: zamieć na minutę / HP Maga L100", "68%", fmtValue(v("vaelgrath.blizzard"), "%"), "≤ 60%" },
		{ "Vaelgrath: tick burzy / HP Maga L100", "47%", fmtValue(v("vaelgrath.storm"), "%"), "30–45%" },
		{
			"Vaelgrath: fala tarczy, HP na członka (3 / 4 / 5)",
			"291% / 198% / 191%",
			three("vaelgrath.wave", "", "%"),
			"≤ 110%",
		},
		{
			"Vaelgrath: nietykalność fazy 2 / max(lot, fala) (3 / 4 / 5)",
			"1,00 (model)",
			three("vaelgrath.flight", "", "2"),
			"1,00",
		},
		{
			"Vaelgrath: G11 (najmniejsze tempo ataku; pierścień w fazie 3)",
			"53% (pierścień 53%)",
			fmtValue(regionMin("bossCadence"), "%"),
			"≥ 50%",
		},
		{ "Vaelgrath: T-SK6 Uzdrowiciela lochowego", "5,98", fmtValue(v("vaelgrath.tsk6"), "2"), "1,0–2,0" },
		{
			"Vaelgrath bez wsparcia 3 / 4 / 5: s",
			"89 / 90 / 89",
			three("vaelgrath.noSupport.", ".seconds", "1"),
			"≤ 480",
		},
		{
			"Vaelgrath bez wsparcia: przyjmowane / podtrzymanie (najgorszy, 3 / 4 / 5)",
			"0,60 / 0,61 / 0,63",
			three("vaelgrath.noSupport.", ".sustain", "2"),
			"≤ 1,0",
		},
		{
			"Vaelgrath bez wsparcia: największy cios / HP członka",
			"117%",
			fmtValue(v("vaelgrath.noSupport.3.hit"), "%"),
			"≤ 100%",
		},
		{ "Vaelgrath: Mityki nieużyteczne (4 klasy)", "0%", range("R.frostpeak.vaelgrath.mythic.", "%"), "0%" },
		{
			"Vaelgrath: zabicia do Mityka / Grimrok",
			"1,00 (50 / 50)",
			`{fmtValue(v("vaelgrath.mythicLadder"), "2")} ({fmtValue(B.expectedMythicKills("vaelgrath"), "0")} / {fmtValue(
				B.expectedMythicKills("grimrok"),
				"0"
			)})`,
			"1,4–1,6",
		},
		{
			"Elity pojedyncze w paśmie (20–36 s, 55–95%)",
			"44%",
			fmtValue(share("eliteSingle"), "%"),
			"≥ 72%",
		},
		{
			"Elity: spotkanie Wojownik / Mag (najgorsze)",
			"185% / 211%",
			`{fmtValue(regionMax("eliteEncounter", "Warrior"), "%")} / {fmtValue(
				regionMax("eliteEncounter", "Mage"),
				"%"
			)}`,
			"≤ 110% / ≤ 125%",
		},
		{
			"Elita II solo / 2 / 3 graczy",
			"2,79–4,52 / 1,11–1,93 / 0,75–1,27",
			`{regionRange("elite2", ".solo", "2")} / {regionRange("elite2", ".duo", "2")} / {regionRange(
				"elite2",
				".trio",
				"2"
			)}`,
			"≥ 1,8 / ≤ 1,5 / 0,6–1,0",
		},
		{ "Elity dropią ilvl 71–100", "29/30", count("R.frostpeak.ilvl.elite"), "każdy" },
		{ "Expowiska ≥ 2 na 71–100", "22/30", count("R.frostpeak.areas."), "każdy" },
		{
			"Rodzaje: EXP/s ÷ zwykły (najmniej)",
			"0,70 (crystalGuardian)",
			fmtValue(regionMin("kinds", ".exp"), "2"),
			"0,85–1,20",
		},
		{
			"Lodowy Żywiołak: HP/EXP ÷ średnia regionu",
			"1,11",
			fmtValue(regionMax("kinds", nil, ".casterHp"), "2"),
			"≤ 1,25",
		},
		{ "Tempo 70 → 100 (okno): h", "40,89", fmtValue(pace, "2"), "34,9–47,2" },
		{
			"Tempo: h(99) / największy krok h(L) / h(L − 1) na 70–99",
			"1,66 / (h(92) = 0: okno `glacier` tylko na 92.)",
			`{fmtValue(v("pace.h99"), "2")} / {fmtValue(step, "2")}`,
			"1,36–1,84 / ≤ 1,30",
		},
		{ "Tempo 1 → 100 (okno): h", "84,05", fmtValue(v("pace.total"), "2"), "69,7–94,3" },
		{
			"Plecak 160 (od 65.) / 200 (od 80.): poziomy dochodu",
			"21,7 / 33,8",
			`{fmtValue(v("gold.backpack_160.Warrior"), "1")} / {fmtValue(v("gold.backpack_200.Warrior"), "1")}`,
			"5–12",
		},
		{ "+1…+3 broni / dochód poziomu (71–99)", "0,63–0,84", range("R.frostpeak.gold.up3", "2"), "≤ 1,05" },
		{
			"Mikstury łańcuchowe / dochód (71–99)",
			"0,38–1,45",
			range("R.frostpeak.gold.chain.", "2"),
			"0,15–0,30 (górna: raport)",
		},
		{
			"Złoto za 1 HP: Potężna − Wielka",
			"0,125",
			fmtValue(v("gold.potionOrder.5"), "g"),
			"≥ 0",
		},
		{
			"Rudy u kowala: mithril / adamantyt od poziomu",
			"brak / brak",
			`{fmtValue(v("gold.ore.ore_mithril"), "0")} / {fmtValue(v("gold.ore.ore_adamantite"), "0")}`,
			"70 / 90",
		},
		{
			"Komplet +9 z ochroną: h na Iglicy Wyrmów (Wojownik L99)",
			"399",
			fmtValue(v("gold.set9"), "0"),
			"150–300 (raport)",
		},
		{ "D5 (K0): Unikaty dla klasy na h expienia", "2,81–4,19", regionRange("d5", ".unique", "2"), "2–4" },
		{ "D5 (K0): Heroiki na h Elit", "0,63–0,87", regionRange("d5", ".heroic", "2"), "0,5–1,5" },
		{
			"Części: rodzaje z częścią / części w przepisach / futro i łuska od 70 / eliksir lodu",
			"7/12 / 4/5 / 0/2 / 30",
			`{count("R.frostpeak.parts.kind")} / {count("R.frostpeak.parts.recipe")} / {count("R.frostpeak.parts.late")} / {fmtValue(
				v("parts.elixirIce"),
				"0"
			)}`,
			"12/12 / 5/5 / 2/2 / 70",
		},
		{ "`support.elites` na 80 / 95", "0/10", count("R.frostpeak.support"), "10/10 (raport)" },
	}
	tableOut({ "liczba", "start S94", "teraz", "cel" }, rows)
	local listed: { B.TargetRow } = {}
	for _, row in s94Rows do
		if row.group ~= "guards" and not string.find(row.id, "gold.", 1, true) and row.group ~= "pace" then
			table.insert(listed, row)
		end
	end
	local ok, all = countIn(s94Rows)
	add("### Cele S94 (`Balance.targetsS94`)")
	add()
	add(
		`{ok}/{all} w paśmie (z wierszami raportu). Strażniki T-SK, złoto i tempo w tabelach niżej; pozostałe wiersze regionu (Elity, Elity II, rodzaje, harmonogram, D5) w „Cele (70–100)”.`
	)
	add()
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(listed, "S94 (asertowane)"))
	-- guards matrix (H1)
	add("### Strażniki T-SK w paśmie (S94, H1)")
	add()
	add(
		"T-SK1 / T-SK2 względem własnego L20 (limity 1,15 / 1,25) i T-SK3 / areaCap (≤ 1) na 75 / 80 / 85 / 90 / 95 / 99 / 100 (rzędy 10–11 według punktów). Gwiazdka: wiersz w raporcie (na 70 build ma już wartość ponad limitem planu D1, reguła S92 / S93, albo powód grupy w `Balance.S94_REPORT`); T-SK4 Maga i T-SK5 Uzdrowiciela lochowego w „Cele S94”."
	)
	add()
	local gRows: { { string } } = {}
	for _, c in B.CLASSES do
		for _, build in SkillModel.builds(c) do
			local cells = { `{c} {build.key}` }
			for _, L in S.guardLevels do
				local g = SkillModel.guards(build, L)
				local mark = ""
				for _, metric in { "tsk1", "tsk2", "tsk3" } do
					local row = byId[`R.frostpeak.guard.{metric}.{c}.{build.key}.{L}`]
					if row and row.report and not B.inBand(row) then
						mark = "*"
					end
				end
				table.insert(
					cells,
					`{fmtValue(g.tsk1rel, "2")} / {fmtValue(g.tsk2rel, "2")} / {fmtValue(g.tsk3cap, "2")}{mark}`
				)
			end
			table.insert(gRows, cells)
		end
	end
	tableOut({ "build", "75", "80", "85", "90", "95", "99", "100" }, gRows)
	-- pace (G)
	add("### Tempo 69 → 100 i całe 1 → 100 (model okna S91, Wojownik; S94)")
	add()
	add(
		"h = godziny na poziom (rodzaj zwykły, odpoczynek, zadania główne bez bossów w oknach, poboczne 0,5); m = średnia krocząca h(L − 4..L) (raport); „rodzaj regionu” = `kindAtRegion` (raport); „z Vaelgrathem” = zadanie `vaelgrath` (97, `exp(99, 1,5)`) w oknie (raport). S94: okno ostatniego zadania głównego (`glacier`) sięga 99. (DECYZJE S94)."
	)
	add()
	local pRows: { { string } } = {}
	for L = 69, 100 do
		local h = B.paceWindowAt("Warrior", L).hours
		local prev = B.paceWindowAt("Warrior", L - 1).hours
		table.insert(pRows, {
			tostring(L),
			fmtValue(h, "2"),
			fmtValue(h / math.max(1e-9, prev), "2"),
			fmtValue(B.paceWindowMean("Warrior", L), "2"),
			fmtValue(B.paceWindowAt("Warrior", L, { kind = "region" }).hours, "2"),
			fmtValue(B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours, "2"),
		})
	end
	tableOut({ "poziom", "h", "h / h(L − 1)", "m", "h rodzaj regionu", "h z Vaelgrathem" }, pRows)
	local bands = { { 1, 19 }, { 20, 44 }, { 45, 69 }, { 70, 99 } }
	local bandRows: { { string } } = {}
	local total, totalBoss = 0, 0
	for _, b in bands do
		local sum, boss = 0, 0
		for L = b[1], b[2] do
			sum += B.paceWindowAt("Warrior", L).hours
			boss += B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours
		end
		total += sum
		totalBoss += boss
		table.insert(bandRows, { `{b[1]} → {b[2] + 1}`, fmtValue(sum, "2"), fmtValue(boss, "2") })
	end
	table.insert(bandRows, { "1 → 100", fmtValue(total, "2"), fmtValue(totalBoss, "2") })
	tableOut({ "pasmo", "h (bez bossów)", "h z zadaniami bossów" }, bandRows)
	do
		local need = 0
		for L = 62, 71 do
			need += B.paceWindowAt("Warrior", L).questExp
		end
		local inBand = B.paceWindowAt("Warrior", 70).questExp + B.paceWindowAt("Warrior", 71).questExp
		add(
			`Zadanie \`vaelgrath\` oddaje {fmtValue(B.questsAt(97, { bosses = true }).exp - B.questsAt(97).exp, "0")} EXP (z Vaelgrathem w oknie −{fmtValue(
				pace
					- (function()
						local s = 0
						for L = 70, 99 do
							s += B.paceWindowAt("Warrior", L, { withBossQuests = true }).hours
						end
						return s
					end)(),
				"2"
			)} h na 70 → 100); okno zadania \`deepforge\` (62–71) daje na 70.–71. {fmtValue(
				inBand / math.max(1e-9, need),
				"%"
			)} EXP zadań tego okna.`
		)
		add()
	end
	-- class premium (ROZWOJ 7.4)
	local premium: { { string } } = {}
	for _, L in { 80, 95 } do
		for _, party in { { "Warrior", "Warrior", "Warrior" }, { "Warrior", "Hunter", "Mage" } } do
			local p = B.paceAt("Warrior", L, { party = party })
			table.insert(premium, {
				`{L}: {table.concat(party, " + ")}`,
				fmtValue(p.expMul, "2"),
				fmtValue(p.expPerHour, "g"),
			})
		end
	end
	add("### Premia za różne klasy (tylko raport, S94)")
	add()
	tableOut({ "drużyna 3 osób", "mnożnik EXP", "EXP/h członka" }, premium)
	-- chain potions (J2)
	add("### Mikstury łańcuchowe ÷ dochód (S94, J2; górna granica 30% w raporcie, dolna 15% asertowana)")
	add()
	local chain: { { string } } = {}
	for L = 71, 99, 4 do
		local cells = { tostring(L) }
		for _, c in B.CLASSES do
			table.insert(cells, fmtValue(B.economyAt(c, L, { potions = "chain" }).potionShare, "%"))
		end
		table.insert(chain, cells)
	end
	tableOut({ "poziom", "Wojownik", "Łowca", "Mag", "Kapłan" }, chain)
	-- gold endgame (J)
	add("### Złoto endgame'u (S94, J)")
	add()
	local jRows: { { string } } = {}
	for _, c in B.CLASSES do
		local set = B.protectedSet(c, 99)
		table.insert(jRows, {
			`komplet +9 z ochroną, {c} L99 ({set.area})`,
			`{fmtValue(set.goldEq, "0")} zł ekw., {fmtValue(set.scrolls, "0")} zwojów, {fmtValue(set.cores, "0")} Rdzeni; {fmtValue(
				set.perHour,
				"0"
			)} zł/h → {fmtValue(set.hours, "0")} h`,
		})
	end
	for _, ilvl in { 75, 85, 99 } do
		local f = B.protectedFlow(ilvl)
		table.insert(jRows, {
			`chroniony +9 broni ilvl {ilvl} (Rdzenie i zwoje)`,
			`{fmtValue(f.gold, "0")} zł, {fmtValue(f.scrolls, "1")} zwojów ({fmtValue(f.scrollGold, "0")} zł), {fmtValue(
				f.cores,
				"1"
			)} Rdzeni = {fmtValue(f.levels, "1")} poziomu dochodu`,
		})
	end
	do
		local GuildSkills = require("../src/shared/Data/GuildSkills")
		local allGuild = 0
		for _, s in GuildSkills.list do
			for i = 1, math.min(5, #s.costs) do
				allGuild += s.costs[i]
			end
		end
		local perHour = B.protectedSet("Warrior", 99).perHour
		table.insert(jRows, {
			"umiejętności gildii do 5 (skarbiec gildii)",
			`{fmtValue(allGuild, "0")} zł = {fmtValue(allGuild / math.max(1e-9, perHour), "0")} h Wojownika L99`,
		})
		local Recipes = require("../src/shared/Data/Recipes")
		local blessing = (Recipes.get("blessing_fortune_4") :: any).gold
		table.insert(jRows, {
			"Legendarne błogosławieństwo podtrzymane (2 na godzinę)",
			`{fmtValue(2 * blessing, "0")} zł/h = {fmtValue(2 * blessing / math.max(1e-9, perHour), "%")} dochodu L99`,
		})
		local Crafting = require("../src/shared/Data/Crafting")
		local Items = require("../src/shared/Data/Items")
		for _, tier in { 70, 80, 90, 100 } do
			local r = Crafting.get(`armor_heavy_{tier}`) :: any
			local gold = r.gold
			for _, m in r.materials do
				local mat = Items.get(m.id) :: any
				gold += m.n * (if mat then (mat.price or 0) * 4 else 0)
			end
			local income = B.levelIncome("Warrior", math.min(99, tier))
			table.insert(jRows, {
				`wytworzenie zbroi ciężkiej {tier} (złoto + materiały po 4 × cenie)`,
				`{fmtValue(gold, "0")} zł = {fmtValue(gold / math.max(1e-9, income), "2")} poziomu dochodu`,
			})
		end
	end
	tableOut({ "pozycja", "wartość" }, jRows)
	-- D5 with luck (I3)
	add("### D5 ze szczęściem (tylko raport, S94)")
	add()
	add(
		"Unikaty dla klasy na h expienia / Heroiki na h Elit: K0, K1, K1 z Kapłanem Fortuny, K2 z Kapłanem Fortuny (profile S84 / S88; limit szczęścia `monsterItemCap`)."
	)
	add()
	local d5: { { string } } = {}
	for _, L in { 75, 85, 95, 99 } do
		for _, c in { "Warrior", "Cleric" } do
			local cells = { `{c} {L}` }
			for _, spec in { { "K0", false }, { "K1", false }, { "K1", "full" }, { "K2", "full" } } do
				local d = B.dropsPerHour(c, L, spec[1] :: string, spec[2] :: any)
				table.insert(cells, `{fmtValue(d.unique, "2")} / {fmtValue(d.heroic, "2")}`)
			end
			table.insert(d5, cells)
		end
	end
	tableOut({ "klasa · poziom", "K0", "K1", "K1 + Fortuna", "K2 + Fortuna" }, d5)
	do
		local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
		local w = Rarities.dropWeights.elite2 :: any
		local drops = Rarities.itemDrops.elite2 :: any
		local f = LevelCurves.dropFactor("frostpeak")
		local share = w[Rarities.LEGENDARY] / (f * (w[Rarities.UNIQUE] + w[Rarities.HEROIC]) + w[Rarities.LEGENDARY])
		local perKill = drops.chance * (drops.min + drops.max) / 2 * share
		local span = AreaSpawns.elite2Respawn(95)
		local respawn = (span.min + span.max) / 2
		local Loot = require("../src/shared/Logic/Loot")
		local boss = 0
		for k = 0, Config.Boss.dailyRuns - 1 do
			boss += #B.REGION_IDS * Loot.bossChances("vaelgrath", k).legendary
		end
		add(
			`Legendarne z obozowania przy Elicie II (Serce Lodowca, poziom 95, odrodzenie {fmtValue(respawn / 60, "1")} min): {fmtValue(
				perKill * 3600 / respawn,
				"2"
			)} na godzinę na jaskinię; z bossów (4 bossy × {Config.Boss.dailyRuns} zabicia dziennie): {fmtValue(
				boss,
				"2"
			)} na dobę.`
		)
		add()
	end
	-- pairs alone and casters (report)
	add("### Pary Elit i rodzaje rzucające (tylko raport, S94)")
	add()
	local pairRows: { { string } } = {}
	for _, cave in B.caveElites("frostpeak") do
		for _, kind in cave.kinds do
			local worst = 0
			for _, fight in kind.fights do
				worst = math.max(worst, fight.pair.hpLost / math.max(1e-9, fight.single.hpLost))
			end
			table.insert(pairRows, { `{cave.id} {kind.kind}`, fmtValue(cave.pairShare, "%"), fmtValue(worst, "2") })
		end
	end
	tableOut({ "jaskinia · rodzaj", "q par", "para ÷ pojedyncza (najwięcej; cel ≤ 2,6)" }, pairRows)
	-- Vaelgrath extras (C)
	add("### Vaelgrath: tylko raport (S94)")
	add()
	local def = Bosses.byId.vaelgrath :: any
	local vRows: { { string } } = {}
	for n = 3, 5 do
		local r = B.bossNoSupport("vaelgrath", n)
		local pots = {}
		for _, mem in r.members do
			table.insert(pots, `{mem.key} {fmtValue(mem.potions, "1")}`)
		end
		table.insert(vRows, { `bez wsparcia, {n} graczy: mikstury na walkę`, table.concat(pots, ", ") })
	end
	do
		local team = B.team(5, S.bossLevel)
		team[2] = B.player("Mage", 100)
		local cells = {}
		for _, hs in { 0, 0.5, 1 } do
			local f = B.bossFight("vaelgrath", team, { hazardShare = hs })
			table.insert(
				cells,
				`{fmtValue(hs, "1")}: tank {fmtValue(f.phases[3].tankDps * 60 / team[1].values.maxHp, "%")}/min`
			)
		end
		table.insert(vRows, { "burza przy hazardShare 0 / 0,5 / 1 (faza 3)", table.concat(cells, ", ") })
	end
	local waves = {}
	for n = 3, 5 do
		local f = B.bossFight("vaelgrath", B.team(n, S.bossLevel))
		local ws = B.shieldWaves("vaelgrath", B.team(n, S.bossLevel))
		table.insert(
			waves,
			`{n}: fale {fmtValue(ws[1].seconds, "1")} / {fmtValue(ws[2].seconds, "1")} s, okno fazy 2 {fmtValue(
				f.phases[2].shieldSeconds + f.phases[2].flightSeconds,
				"1"
			)} s (lot po fali {fmtValue(f.phases[2].flightSeconds, "1")} s)`
		)
	end
	table.insert(vRows, { "fale tarczy i okno bez obrażeń w fazie 2 (drużyna S32)", table.concat(waves, "; ") })
	local m = B.monster(B.bossKind(def, 4), def.level, "boss")
	for _, key in { "trapper.poisoner", "inquisitor.solo" } do
		local sp = SkillModel.player(SkillModel.build(key), S.bossLevel)
		local d60 = SkillModel.fight(sp, { targets = { m }, seconds = 60 }).dps
		local d300 = SkillModel.fight(sp, { targets = { m }, seconds = 300 }).dps
		table.insert(vRows, {
			`{key} na Vaelgracie: DPS 300 s ÷ DPS 60 s`,
			`{fmtValue(d300 / math.max(1e-9, d60), "2")} ({fmtValue(d60, "g")} → {fmtValue(d300, "g")})`,
		})
	end
	for phase = 1, 3 do
		local cad = B.bossCadence(def, phase)
		local parts = {}
		for _, at in def.attacks do
			if cad.perMinute[at.id] then
				table.insert(
					parts,
					`{at.id} {fmtValue(cad.perMinute[at.id], "1")}/min ({fmtValue(cad.rateShare[at.id], "%")})`
				)
			end
		end
		table.insert(vRows, { `harmonogram fazy {phase}`, table.concat(parts, ", ") })
	end
	for _, bossId in { "grimrok", "morvane", "azgor", "vaelgrath" } do
		local kills = B.expectedMythicKills(bossId)
		table.insert(vRows, {
			`{bossId}: oczekiwane zabicia / dni do Mityka (3 dziennie, K0)`,
			`{fmtValue(kills, "0")} / {fmtValue(kills / Config.Boss.dailyRuns, "1")}`,
		})
	end
	tableOut({ "liczba", "wartość" }, vRows)
	-- R4 in the band (H3, H4)
	add("### Przełomy A / B osiągane w 71–95 (tylko raport, S94, H3)")
	add()
	add(
		"R4 = zysk opcji w roli umiejętności na poziomie rangi (S89 E1, `SkillModel.optionGain`); pasmo 0,08–0,17 (5) i 0,17–0,28 (10); opcje użytkowe (`R4_UTILITY`) bez liczby. Gniew Żywiołów 10A / 10B (H4) na 84. w buildzie Niszczyciela jest w tabeli."
	)
	add()
	local r4Rows: { { string } } = {}
	for _, classId in B.CLASSES do
		for _, d in SkillData.byClass[classId] do
			local def2: any = d
			if def2.type == "passive" or not def2.breakpoints then
				continue
			end
			local key = SkillModel.R4_SUPPORT_BUILDS[def2.id]
				or (if def2.path then SkillModel.R4_PATH_BUILDS[def2.path] else SkillModel.R4_CLASS_BUILDS[classId])
			local build = SkillModel.build(key)
			for _, at in Skills.BREAKPOINT_LEVELS do
				local rankLevel = Skills.rankLevel(def2, at)
				if rankLevel > 70 and rankLevel <= 95 and def2.breakpoints[at] then
					local cells = { `{def2.id} {at} ({key})`, tostring(rankLevel) }
					for _, choice in { "a", "b" } do
						local k = `{def2.id}:{at}{choice}`
						if SkillModel.R4_UTILITY[k] then
							table.insert(cells, "użyteczność")
						else
							local g = SkillModel.optionGain(build, def2.id, at, choice, rankLevel)
							table.insert(cells, if g then fmtValue(g, "2") else "–")
						end
					end
					table.insert(r4Rows, cells)
				end
			end
		end
	end
	tableOut({ "umiejętność · przełom (build)", "poziom", "A", "B" }, r4Rows)
	-- anchors 100 (S94)
	add("### Kotwice 100 (S94)")
	add()
	add(
		"S94 nie przestawiło żadnej kotwicy 100 (`monsterHp`, `monsterAtk`, `eliteHp`, `eliteDmg`, `elite2*`, `expToNext`, `manaCost.Mage`, `heal`): wiersze pasma (Elity, Elity II, tempo 70 → 100 i 1 → 100, T-SK4, T-SK5) mieszczą się w celach na krzywych S87 po zmianach rodzajów i jaskiń. Wartości:"
	)
	add()
	local kRows: { { string } } = {}
	for _, id in LevelCurves.ids() do
		table.insert(kRows, { id, fmtValue(LevelCurves.at(id, 85), "2"), fmtValue(LevelCurves.at(id, 100), "2") })
	end
	tableOut({ "krzywa", "85", "100" }, kRows)
end

local REGION_SESSION = { "S91", "S92", "S93", "S94" }
for i, band in B.BANDS do
	local lo, hi = band[1], band[2]
	local mapId = B.REGION_IDS[i]
	-- S94 (L3): no TUNED gate any more; every band is tuned and asserted
	add(`## Pasmo {lo}–{hi} ({mapId})`)
	add()
	for _, t in byBand[`{lo}-{hi}`] or {} do
		renderTable(t, "###")
	end
	if lo == 1 then
		local s32 = B.targets1_20()
		local ok, all = countIn(s32)
		add("### Cele 1–20 (S32 i S91)")
		add()
		add(
			`{ok}/{all} w paśmie. S91: poziomy 1–20 przestrojone i zamrożone. Bloki S32 w \`balance.spec\` asertują znowu (gracz konwencji bez węzłów i z węzłami buildów wzorcowych przyciętych do poziomu, wiersze „@<build>”), nowe cele S91 (tempo z modelu okna, Grimrok w modelu S83 / S87, T-SK6, bez wsparcia, warstwa umiejętności na L20, R4 rangi 5, ścieżki na 20) w bloku „Balance 1-20: S91”; wiersze z opisem w kolumnie „kto asertuje” są poza zasięgiem dźwigni S91 (raport). Liczby „przed” (start S91) i porównanie z 05b859d: \`docs/SESJE.md\` → S91.`
		)
		add()
		tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, targetRows(s32, "S91 (asertowane)"))
		local fixture = BalanceTables.fixtureDiff(BalanceTables.ALLOWED_1_20_DIFFS)
		local tolerance = fmtValue(BalanceTables.FIXTURE_TOLERANCE * 100, "1")
		add(
			`G12 (fixture 1–20): {#fixture.diffs} różnic powyżej {tolerance}% ({#fixture.diffs - fixture.unexpected} `
				.. `dozwolonych), {#fixture.missing} brakujących kluczy `
				.. "(`tests/balance1_20.spec.luau`, tryb ścisły od S91, lista `BalanceTables.ALLOWED_1_20_DIFFS`)."
		)
		add()
		-- S91 (I1): the accepted state before the rebuild (05b859d, docs/BALANS.md of S32) next to now
		add("### Przed przebudową (05b859d) a S91")
		add()
		local now: { { string } } = {}
		local refs = {
			{ "1 na 1 L20 Wojownik: s / HP", "7,6 s / 15%", "Warrior" },
			{ "1 na 1 L20 Łowca: s / HP", "6,1 s / 15%", "Hunter" },
			{ "1 na 1 L20 Mag: s / HP", "6,1 s / 17%", "Mage" },
			{ "1 na 1 L20 Kapłan: s / HP", "10,4 s / 12%", "Cleric" },
		}
		for _, r in refs do
			local f = B.duel(B.player(r[3], 20), B.monster(B.GENERIC, 20))
			table.insert(now, { r[1], r[2], `{fmtValue(f.seconds, "1")} s / {fmtValue(f.hpLost, "%")}` })
		end
		local soloLo, soloHi, trioLo, trioHi = math.huge, 0, math.huge, 0
		for _, row in s32 do
			if row.group == "elite2" then
				if string.find(row.id, "solo", 1, true) then
					soloLo, soloHi = math.min(soloLo, row.value), math.max(soloHi, row.value)
				elseif string.find(row.id, "trio", 1, true) then
					trioLo, trioHi = math.min(trioLo, row.value), math.max(trioHi, row.value)
				end
			end
		end
		table.insert(now, {
			"Elita II (S32): solo / 3 graczy HP",
			"238–307% / 72–94%",
			`{fmtValue(soloLo, "%")}–{fmtValue(soloHi, "%")} / {fmtValue(trioLo, "%")}–{fmtValue(trioHi, "%")}`,
		})
		local minutes = {}
		for n = 3, 5 do
			table.insert(minutes, fmtValue(B.bossFight("grimrok", B.team(n, 19)).seconds / 60, "1"))
		end
		table.insert(now, {
			"Grimrok 3 / 4 / 5 graczy (model S83 / S87): min",
			"5,0 / 5,3 / 5,2 (model S32)",
			table.concat(minutes, " / "),
		})
		local mage = B.boss("grimrok", { B.player("Mage", 20) }).biggest[1].share
		table.insert(now, { "Grimrok: największy cios / HP Maga L20 (model S32)", "67%", fmtValue(mage, "%") })
		local hours = 0
		for L = 1, 19 do
			hours += B.paceWindowAt("Warrior", L).hours
		end
		table.insert(now, {
			"Tempo 1 → 20 Wojownika: h",
			"ok. 2,3 (model S32, z Grimrokiem)",
			`{fmtValue(hours, "2")} (model okna, bez Grimroka)`,
		})
		tableOut({ "liczba", "05b859d (S32)", "S91" }, now)
	end
	local gRows = globalFor(lo, hi)
	local regionRows = B.targetsRegion(mapId)
	local cele = targetRows(gRows, "S87")
	local regionWho = `{REGION_SESSION[i]} (asertowane)`
	for _, r in targetRows(regionRows, regionWho) do
		table.insert(cele, r)
	end
	local gOk, gAll = countIn(gRows)
	local rOk, rAll = countIn(regionRows)
	add(`### Cele ({lo}–{hi})`)
	add()
	add(`Globalne (G): {gOk}/{gAll} w paśmie; regionu: {rOk}/{rAll} w paśmie.`)
	add()
	tableOut({ "cel", "wartość", "próg", "wynik", "kto asertuje" }, cele)
	if mapId == "duskwood" then
		s92Section()
	elseif mapId == "ashen" then
		s93Section()
	elseif mapId == "frostpeak" then
		s94Section()
	end
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

-- S95 (I5): a full set from the class vendor ------------------------------------------------------------------

-- Cheapest entry of `slot` at `tier` in the vendor's shop: its price and the item (nil when the class has none).
local function cheapestAt(shop: any, slot: string, tier: number): (number?, string?)
	local best: number?, item: string? = nil, nil
	for _, entry in shop.entries do
		local def = Items.get(entry.item)
		if def and def.slot == slot and entry.ilvl == tier then
			local price = ShopPrice.unit(entry, tier, 0, shop)
			if best == nil or price < best then
				best, item = price, entry.item
			end
		end
	end
	return best, item
end

-- Gold of the smith's recipe plus the materials the smith sells (ores, essence dust) at his prices; hides, fur and
-- scales are monster parts (not counted).
local SMITH_PRICES: { [string]: number } = {}
for _, entry in (Shops.get("blacksmith") :: any).entries do
	SMITH_PRICES[entry.item] = ShopPrice.unit(entry, 100, 0, Shops.get("blacksmith"))
end
local function forgeCost(item: string): number
	local recipe = Crafting.get(item)
	if not recipe then
		return 0
	end
	local total = recipe.gold
	for _, m in recipe.materials do
		total += (SMITH_PRICES[m.id] or 0) * m.n
	end
	return total
end

do
	add("## Komplet u sprzedawcy klasy (S95)")
	add()
	add(
		"Najtańsza broń, druga ręka, hełm, pancerz, rękawice i buty klasy z jednego progu sprzedawcy (Zwykłe, `value × buyMul`), ten sam komplet z kuźni (złoto przepisu + rudy i pył esencji po cenach kowala; skóry, futro i łuski z potworów nie są liczone) i minuty zarobku na poziomie progu (`Balance.economyAt`: złoto i drop z zabić na godzinę). Raport, nie cel."
	)
	add()
	local rows: { { string } } = {}
	local CLASS_NAMES = { Warrior = "Wojownik", Cleric = "Kapłan", Hunter = "Łowca", Mage = "Mag" }
	for _, classId in { "Warrior", "Cleric", "Hunter", "Mage" } do
		local shop = Shops.get(Shops.vendorOf(classId) :: string) :: any
		for _, tier in Shops.WEAPONSMITH_TIERS do
			local price, forge = 0, 0
			for _, slot in Shops.VENDOR_SLOTS do
				local p, item = cheapestAt(shop, slot, tier)
				if p and item then
					price += p
					forge += forgeCost(item)
				end
			end
			local perMinute = B.economyAt(classId, tier).incomePerHour / 60
			table.insert(rows, {
				`{CLASS_NAMES[classId]} {tier}`,
				fmtValue(price, "i"),
				fmtValue(forge, "i"),
				fmtValue(price / math.max(1e-9, perMinute), "1"),
			})
		end
	end
	tableOut({ "klasa · próg", "u sprzedawcy", "kuźnia (złoto + rudy)", "minuty zarobku" }, rows)
end

-- Mounts (S97) ------------------------------------------------------------------------------------------------------

do
	add("## Wierzchowce (S97)")
	add()
	add(
		"Ulepszanie u stajennego (`Data/Mounts.UPGRADE`, ten sam koszt dla każdego wierzchowca): złoto wobec dochodu poziomu przy wymaganym poziomie postaci (`Balance.levelIncome`, średnia klas, jak G9 z S84), części potworów i zabicia najlepszego rodzaju w paśmie ±10 poziomów (szansa części z `LootTables.PARTS`). Asercje w `balance.spec` („S97 mounts”): każdy stopień 0,3–1,0 dochodu, suma 4–8."
	)
	add()
	local rows: { { string } } = {}
	local total, totalGold = 0, 0
	for _, row in B.mountUpgrades() do
		local mats: { string } = {}
		for _, m in row.mats do
			table.insert(mats, `{m.n} {m.id} ({m.kind or "–"}: {m.kills})`)
		end
		total += row.share
		totalGold += row.gold
		table.insert(rows, {
			`{row.to - 1} → {row.to}`,
			tostring(row.level),
			fmtValue(row.gold, "i"),
			fmtValue(row.income, "i"),
			fmtValue(row.share, "2"),
			table.concat(mats, ", "),
			`×{fmtValue(row.speedMul, "2")}`,
			fmtValue(row.mountTime, "1"),
		})
	end
	table.insert(rows, { "1 → 10", "", fmtValue(totalGold, "i"), "", fmtValue(total, "2"), "", "", "" })
	tableOut({
		"poziom wierzchowca",
		"poziom postaci",
		"złoto",
		"dochód poziomu",
		"udział",
		"części (rodzaj: zabicia)",
		"szybkość",
		"wsiadanie s",
	}, rows)
	add(
		"Wierzchowce z bossów (`Data/Mounts.BOSS_DROPS`): osobny rzut każdego zwycięzcy, bez drabiny zabić dnia i bez szczęścia."
	)
	add()
	local drops: { { string } } = {}
	for _, row in B.mountDrops() do
		table.insert(drops, {
			row.boss,
			row.mount or "–",
			fmtValue(row.mountChance * 100, "1") .. "%",
			fmtValue(row.kills, "i"),
			fmtValue(row.days, "1"),
		})
	end
	tableOut({ "boss", "wierzchowiec", "szansa", "zabicia średnio", "dni przy limicie" }, drops)
end

-- Quest EXP budget (S98) ------------------------------------------------------------------------------------------

do
	add("## Budżet EXP zadań (S98)")
	add()
	add(
		"Kontrakt `docs/DESIGN-15.md` §3.2: zadania zastępują część bicia, czas na poziom zostaje z S94. Udział = EXP kategorii zaliczony poziomom pasma w modelu okien (`Balance.questCreditByLevel`) / suma `expToNext` pasma; cel `Data/QuestBudget.TARGET` (razem 30%; audyt i asercje: sekcja „Audyt questów (S109)”). Kompensacja: `MONSTER_EXP_MUL` z `lune run tools/quest_budget.luau` (udział bicia `s / s₀` wobec pliku bazowego `tests/fixtures/quest_budget_base.json`)."
	)
	add()
	local cats = QuestBudgetGen.CATEGORIES
	for _, variant in
		{ { false, "model (poboczne × SIDE_SHARE)" }, { true, "gracz robi wszystko (poboczne w całości)" } }
	do
		add(`Udział EXP zadań w paśmie, {variant[2]}:`)
		add()
		local rows: { { string } } = {}
		for _, band in QuestBudgetGen.shares(variant[1]) do
			local row = { `{band.lo}–{band.hi}` }
			for _, cat in cats do
				table.insert(row, fmtValue(band.byCategory[cat] or 0, "%"))
			end
			table.insert(row, fmtValue(band.total, "%"))
			table.insert(rows, row)
		end
		local target = { "cel" }
		local sum = 0
		for _, cat in cats do
			local t = QuestBudgetData.TARGET[cat] or 0
			sum += t
			table.insert(target, fmtValue(t, "%"))
		end
		table.insert(target, fmtValue(sum, "%"))
		table.insert(rows, target)
		tableOut({ "pasmo", "fabuła", "poboczne", "bossowe", "zlecenia", "razem" }, rows)
	end
	add(
		"Poza budżetem (w ułamku `expToNext` poziomu postaci, nagroda liczona przy odbiorze): dzienne 3 × 0,15 = 0,45 na dzień; tygodniowe 3 × 0,30 = 0,90 na tydzień i zlecenie na bossa 0,50 na tydzień (od 15. poziomu)."
	)
	add()
	local rows: { { string } } = {}
	for _, L in { 1, 5, 10, 15, 19, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 99 } do
		local q = B.questsAt(L)
		local e = Exp.expToNext(L)
		table.insert(rows, {
			tostring(L),
			string.format("%.3f", QuestBudgetData.MONSTER_EXP_MUL[L]),
			fmtValue(Quests.Daily.PER_DAY * (Quests.Daily.reward(L).exp or 0) / e, "2"),
			fmtValue(q.weekly / e, "2"),
		})
	end
	tableOut({ "poziom", "`monsterExpMul`", "dzienne / dzień (× expToNext)", "tygodniowe + boss / tydzień" }, rows)
	add(
		"Godziny bicia na pasmo (Wojownik, model okien): baza = udział bicia S94 × EXP poziomu, teraz = po zadaniach S98 i kompensacji."
	)
	add()
	local base = QuestBudgetGen.base()
	local credit = QuestBudgetGen.credit()
	local hours: { { string } } = {}
	for _, band in QuestBudgetData.BANDS do
		local before, after = 0, 0
		for L = band[1], band[2] do
			local w = B.paceWindowAt("Warrior", L)
			local mul = QuestBudgetData.MONSTER_EXP_MUL[L]
			before += base[L].share * credit[L].exp * mul / w.expPerKill * w.secondsPerKill / 3600
			after += w.hours
		end
		table.insert(
			hours,
			{ `{band[1]}–{band[2]}`, fmtValue(before, "1"), fmtValue(after, "1"), fmtValue(after / before, "2") }
		)
	end
	tableOut({ "pasmo", "h baza", "h teraz", "teraz / baza" }, hours)
end

-- Login reward (S100) ---------------------------------------------------------------------------------------------

do
	add("## Nagroda za logowanie (S100)")
	add()
	add(
		"Tydzień nagród (`Data/LoginReward`, `Logic/LoginReward.week`) wobec dochodu godziny bicia (`Balance.economyAt`): mikstury i kamienie po cenie kupna, esencja po cenach materiałów S84 (`Balance.materialPrices`), błogosławieństwo po cenie przedmiotu; przedmiot skrzyni poza wartością (drop, wiersz pod tabelą). Esencja tygodnia wobec esencji tego rodzaju na całe pasmo ulepszeń broni klasy z ilvl L − 2 (bez ochrony). Asercje w `balance.spec` („Login reward (S100)”): tydzień 0,15–0,6 h, dzień 1–6 ≤ 0,12 h, dzień 7 bez skrzyni ≤ 0,2 h, esencja ≤ 50%, zero EXP, Heroiki skrzyni ≤ 5% D5."
	)
	add()
	local rows: { { string } } = {}
	for _, c in { "Warrior", "Mage" } do
		for _, L in { 10, 20, 30, 45, 60, 70, 85, 99 } do
			local s = B.loginShare(c, L)
			local items = s.week.total - s.week.gold
			table.insert(rows, {
				BalanceTables.CLASS_PL[c],
				tostring(L),
				fmtValue(s.week.gold, "i"),
				fmtValue(items, "i"),
				fmtValue(s.week.total, "i"),
				fmtValue(s.income, "i"),
				fmtValue(s.weekShare, "2"),
				fmtValue(math.max(s.maxDay16, s.day7), "2"),
				`{s.week.essence.n} {s.week.essence.id} / {fmtValue(s.essenceNeed, "1")} ({fmtValue(
					s.essenceShare,
					"%"
				)})`,
			})
		end
	end
	tableOut({
		"klasa",
		"poziom",
		"złoto tygodnia",
		"przedmioty",
		"razem",
		"dochód / h",
		"tydzień h",
		"najdroższy dzień h",
		"esencja tygodnia / pasmo",
	}, rows)
	local chest = B.loginChest()
	add(
		`Skrzynia (dzień 7): {fmtValue(chest.heroic, "2")} Heroika i {fmtValue(chest.unique, "2")} Unikatu na tydzień = {fmtValue(
			chest.heroicShare,
			"%"
		)} Heroików i {fmtValue(chest.uniqueShare, "%")} Unikatów z dolnej granicy D5 przy {B.LOGIN_HOURS_PER_WEEK} h gry tygodniowo.`
	)
	add()
	add("Nagroda poza modelem tempa i `economyAt` (S100, DECYZJE).")
	add()
end

-- World events (S101) -------------------------------------------------------------------------------------------

do
	add("## Wydarzenia świata (S101)")
	add()
	add(
		"Nagroda za wydarzenie (`Logic/WorldEvents.reward`, zwycięstwo, poziom wydarzenia = poziom postaci, bez `expBonus`) przy jednym wydarzeniu na 2 h gry. Udział EXP = EXP nagrody × (godziny bicia poziomu / 2) / EXP poziomu dla klasy z najdłuższym poziomem (`Balance.worldEventShare`; godziny bicia = `expToNext / paceAt.expPerHour`, bez questów, więc górna granica). Asercja w `balance.spec` („World events (S101)”): ≤ 3% na 1–99. Złoto wobec dochodu 2 h bicia tej klasy (`economyAt`), bez asercji. Minuty = ile minut bicia jest wart EXP nagrody. Zabicia fal i Elity II to zwykłe zabicia (zastępują bicie na tym łowisku), poza tym sprawdzeniem."
	)
	add()
	local function pct2(v: number): string
		return (string.gsub(string.format("%.2f%%", v * 100), "%.", ","))
	end
	local rows: { { string } } = {}
	for L = 10, 100, 10 do
		local r = B.worldEventRow(L)
		table.insert(rows, {
			tostring(L),
			BalanceTables.CLASS_PL[r.classId],
			fmtValue(r.exp, "i"),
			pct2(r.share),
			fmtValue(r.gold, "i"),
			pct2(r.goldShare),
			fmtValue(r.minutes, "1"),
		})
	end
	tableOut(
		{ "poziom", "klasa", "EXP nagrody", "udział EXP", "złoto", "złoto / 2 h dochodu", "minuty bicia" },
		rows
	)
	local worst, worstLevel, worstClass = 0, 0, ""
	for L = 1, 99 do
		local share, classId = B.worldEventShare(L)
		if share > worst then
			worst, worstLevel, worstClass = share, L, classId
		end
	end
	add(`Najgorszy poziom 1–99: {worstLevel} ({BalanceTables.CLASS_PL[worstClass]}), {pct2(worst)} (limit 3%).`)
	add()
end

-- Quest audit (S109) ----------------------------------------------------------------------------------------------

do
	add("## Audyt questów (S109)")
	add()
	add(
		"Audyt końcowy serii S98–S108 (`QuestBudgetGen.audit`, cele `QuestBudgetGen.AUDIT`; asercje w `tests/questbudget.spec.luau`, „Quest budget audit (S109)”; wydruk `lune run tools/quest_budget.luau audit`). Wariant **model** = zaliczenie modelu okien (poboczne × `SIDE_SHARE`, jak kompensacja), wariant **all** = gracz robi zlecenie, fabułę, wszystkie poboczne i bossowe; udziały pasm w `all` liczone po poziomie zadania (fabuła bez zadań z celem `boss`: finały rozdziałów poza modelem tempa, jak S91 / S98)."
	)
	add()
	local audit = QuestBudgetGen.audit()
	local cats = QuestBudgetGen.CATEGORIES
	for _, variant in { "model", "all" } do
		add(`Udział EXP zadań w paśmie ({variant}):`)
		add()
		local rows: { { string } } = {}
		for _, band in audit.bands do
			local shares = (band :: any)[variant]
			local row = { `{band.lo}–{band.hi}` }
			for _, cat in cats do
				table.insert(row, fmtValue(shares.byCategory[cat] or 0, "1%"))
			end
			table.insert(row, fmtValue(shares.total, "1%"))
			table.insert(rows, row)
		end
		local target = { "cel" }
		local sum = 0
		for _, cat in cats do
			local t = QuestBudgetData.TARGET[cat] or 0
			sum += t
			table.insert(target, fmtValue(t, "1%"))
		end
		table.insert(target, fmtValue(sum, "1%"))
		table.insert(rows, target)
		tableOut({ "pasmo", "fabuła", "poboczne", "bossowe", "zlecenia", "razem" }, rows)
	end
	add(
		"Poziomy co 5 (`all` w rozkładzie zaliczenia, średnia krocząca z 5 poziomów w paśmie; godziny bicia Wojownika):"
	)
	add()
	local rows: { { string } } = {}
	for _, L in { 1, 5, 10, 15, 19, 20, 25, 30, 35, 40, 44, 45, 50, 55, 60, 65, 69, 70, 75, 80, 85, 90, 95, 99 } do
		local lv = audit.levels[L]
		table.insert(rows, {
			tostring(L),
			fmtValue(lv.exp, "i"),
			fmtValue(lv.all.main or 0, "1%"),
			fmtValue(lv.all.side or 0, "1%"),
			fmtValue(lv.all.boss or 0, "1%"),
			fmtValue(lv.all.contract or 0, "1%"),
			fmtValue(lv.total, "1%"),
			fmtValue(lv.avg, "1%"),
			(string.gsub(string.format("%.3f", lv.mul), "%.", ",")),
			fmtValue(lv.hoursBase, "2"),
			fmtValue(lv.hoursNow, "2"),
		})
	end
	tableOut({
		"L",
		"`expToNext`",
		"fabuła",
		"poboczne",
		"bossowe",
		"zlecenie",
		"razem",
		"średnia 5",
		"`mul`",
		"h baza",
		"h teraz",
	}, rows)
	add("Wiersze celu (T-QB1…T-QB7):")
	add()
	local targetRows: { { string } } = {}
	for _, r in audit.rows do
		local note = r.why or ""
		if #r.outliers > 0 and not r.report then
			note = table.concat(r.outliers, ", ", 1, math.min(8, #r.outliers))
		end
		table.insert(targetRows, {
			`{r.id} {r.label}`,
			(string.gsub(QuestBudgetGen.fmtAuditValue(r.id, r.value), "%.", ",")),
			(string.gsub(QuestBudgetGen.fmtAuditBand(r), "%.", ",")),
			QuestBudgetGen.auditVerdict(r),
			note,
		})
	end
	tableOut({ "wiersz", "wartość", "cel", "wynik", "uwagi" }, targetRows)
	add(
		"Tempo w pięciu wariantach (Wojownik, model okien; godziny pasm jak cele S91–S94): **S94** = udział bicia z pliku bazowego, **teraz** = `paceWindowAt` (asercje S91–S94), **bez zadań** = cały poziom z potworów z mnożnikiem (w nawiasie gracz bez zadań w S94, bez mnożnika), **wszystko** = zlecenie, fabuła, wszystkie poboczne i bossowe w pełnej wartości, **wszystko + dodatki** = do tego dzienne, tygodniowe, zlecenie na bossa i wydarzenia według `Balance.PLAY_PROFILE` (EXP dodatków na godzinę gry dodany do tempa bicia)."
	)
	add()
	local hourRows: { { string } } = {}
	for _, h in audit.hours do
		table.insert(hourRows, {
			`{h.lo} → {h.hi}`,
			fmtValue(h.s94, "1"),
			fmtValue(h.now, "1"),
			`{fmtValue(h.noQuests, "1")} ({fmtValue(h.noQuestsS94, "1")})`,
			fmtValue(h.allQuests, "1"),
			fmtValue(h.allExtras, "1"),
		})
	end
	tableOut({ "pasmo", "S94 h", "teraz h", "bez zadań h (S94)", "wszystko h", "wszystko + dodatki h" }, hourRows)
	add(
		`Pominięte w modelu (zadania fabuły z celem \`boss\`): {table.concat(audit.skipped, ", ")}. Plik bazowy \`tests/fixtures/quest_budget_base.json\` (S98) jest stały: tryb \`base\` go nie nadpisuje (S109).`
	)
	add()
end

-- Full income (S109) ------------------------------------------------------------------------------------------------

do
	add("## Pełny dochód (S109)")
	add()
	add(
		"Złoto na godzinę gry gracza, który robi wszystko (`Balance.fullIncomeReport`): dochód z gry (`economyAt`: monety i sprzedaż dropu), złoto zadań jednorazowych w rozkładzie zaliczenia EXP (`Balance.questGoldByLevel`) na godziny bicia poziomu, dodatki (`Balance.extrasPerHour`, samo złoto: przedmioty z nagród to zużywalne, jak skrzynie S100 / S101). Asercje w `balance.spec` („Full income (S109)”): górne granice S84 / S92–S94 dalej na dochodzie z gry, dolne (plecaki, komplet +9, mikstury łańcuchowe) na pełnym dochodzie."
	)
	add()
	local rows: { { string } } = {}
	for _, c in B.FULL_INCOME.reportClasses do
		for _, L in B.FULL_INCOME.reportLevels do
			local r = B.fullIncomeReport(c, L)
			table.insert(rows, {
				BalanceTables.CLASS_PL[c],
				tostring(L),
				fmtValue(r.grind, "i"),
				fmtValue(r.quests, "i"),
				fmtValue(r.extras.daily, "i"),
				fmtValue(r.extras.weekly, "i"),
				fmtValue(r.extras.bossContract, "i"),
				fmtValue(r.extras.login, "i"),
				fmtValue(r.extras.events, "i"),
				fmtValue(r.total, "i"),
				fmtValue(r.quests / math.max(1e-9, r.grind), "%"),
				fmtValue(r.extras.total / math.max(1e-9, r.grind), "%"),
			})
		end
	end
	tableOut({
		"klasa",
		"L",
		"z gry / h",
		"zadania / h",
		"dzienne",
		"tygodniowe",
		"boss",
		"logowanie",
		"wydarzenia",
		"razem / h",
		"zadania / gra",
		"dodatki / gra",
	}, rows)
	add(
		`Dzienne, tygodniowe, logowanie i wydarzenia są poza \`economyAt\` i modelem tempa; pełny dochód zakłada \`PLAY_PROFILE\` ({B.PLAY_PROFILE.hoursPerDay} h dziennie).`
	)
	add()
	local targetRows: { { string } } = {}
	for _, r in B.fullIncomeRows() do
		local band = if r.band.lo and r.band.hi
			then `{fmtValue(r.band.lo, "2")}–{fmtValue(r.band.hi, "2")}`
			elseif r.band.lo then `≥ {fmtValue(r.band.lo, "2")}`
			else `≤ {fmtValue(r.band.hi or 0, "2")}`
		table.insert(targetRows, {
			`{r.id} {r.label}`,
			fmtValue(r.value, "2"),
			band,
			if r.report then "raport" elseif r.ok then "OK" else "POZA",
			r.worst or "",
			r.why or "",
		})
	end
	tableOut({ "wiersz", "wartość", "cel", "wynik", "gdzie", "uwagi" }, targetRows)
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
		`{mOk}/{mAll} w paśmie; blok regionów \`balance.spec\` asertuje wiersze bez \`report\` (S86, S91), reszta drukowana z powodem.`
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
		"Mechaniki klas S69–S81 w silniku `tests/SkillModel.luau` (leczenie i tarcze od maks. HP celu, kości i koło jako wartość oczekiwana, podpalenie, pole leczenia, Furia krok po kroku, blok, przechwyt, pułapki, sokół, celowanie, strumień, Ładunki Arkanów, kumulowanie, próg obszaru; każda z `-- mirrors`), cechy broni na zdarzeniu na ekwipunku konwencji S32 (Zwykły, ilvl = poziom − 2), walka z potworami, które oddają, metryki ścieżek i cele ROZWOJ jako wiersze `PATH_TARGETS`. To tylko raport: G10 asertuje S87, ścieżki Kapłana i Wojownika S89, Łowcy i Maga S90, cele 1–20 na L20 S91 (blok „Balance 1-20: S91”), regiony i bossy S92–S94. Fixture: `tests/fixtures/balance_paths.json` (`lune run tools/balance_report.luau --fixture-paths`)."
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
	tableOut({
		"poziom",
		"Wojownik EXP/h łańcuch / odpoczynek",
		"Wojownik mikstury / dochód",
		"Mag EXP/h",
		"Mag mikstury / dochód",
	}, rows)
	rows = {}
	for _, L in { 45, 70, 100 } do
		local def, f = B.bossFightAt("Warrior", L)
		table.insert(rows, {
			`{def.id} ({L})`,
			fmtValue(f.potionHps, "i"),
			fmtValue(f.tankDps, "i"),
			fmtValue(f.potionHps / math.max(1e-9, f.tankDps), "%"),
		})
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
		"Zwykły +0 na 20 / 45 / 70 / 100 (20. tylko raport: S91 nie zmienia przedmiotów) i Mityczny +9; pasmo 4–6% (dwuręczne Maga i Kapłana po E6 do 9%). „Węzły” = z węzłami wzmacniającymi cechę (≤ 8%), „raport” = sytuacje drukowane (zero strukturalne modelu: fale bossa to grupa, Uzdrowiciel nie traci HP w pojedynku)."
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
					row.reportElements == nil
					or (v.element ~= nil and table.find(row.reportElements, v.element) ~= nil)
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
	tableOut({
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
	}, rows)
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
		`Unik: harpia (beast) {beast.dodge}% (S88: 15 → 10), ryś / nietoperz / lampart (animal) {animal.dodge}% (wspólny z rysiem z Łąk; S91: decyzja właściciela, Data/Families). Bossowie bez zmian (S66; życie i ataki S92–S94).`
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
	tableOut({
		"build, broń · poziom",
		"blok / limit",
		"kontra / limit",
		"unik+blok / limit",
		"EHP obu cech",
		"leczenie z bloku / s",
	}, rows)
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
	tableOut({
		"profil · poziom",
		"Unikaty / h",
		"Heroiki / h",
		"Legenda / Elita II",
		"szczęście przed limitem",
		"ucięte przez limit",
		"ucięte na Elicie",
	}, rows)
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

-- S128: Arena Tokens and the arena shop (H2) -------------------------------------------------------------------

do
	local arena = B.arenaTokens()
	add("## Arena: Żetony i sklep (S128)")
	add()
	add(
		"Żetony Areny za mecz (`Data/Arena.TOKENS`, `ArenaRules.tokensFor`): 50% wygranych, premia ×2 na pierwsze 3 mecze dnia (1 na 1 i 3 na 3 razem), limit tygodnia od poniedziałku 00:00 UTC. Nic za Robux ani odłamki."
	)
	add()
	local profileNames = {
		["1v1x3"] = "3 mecze 1 na 1 dziennie",
		["1v1x10"] = "10 meczów 1 na 1 dziennie",
		["3v3x3"] = "3 mecze 3 na 3 dziennie",
	}
	local rows = {}
	for _, p in arena.profiles do
		table.insert(rows, {
			profileNames[p.id] or p.id,
			fmtValue(p.perDay, "1"),
			fmtValue(p.perWeek, "0"),
			fmtValue(p.capDays, "1"),
		})
	end
	tableOut({ "profil", "Żetony / dzień", "Żetony / tydzień (limit)", `dni do limitu {arena.cap}` }, rows)
	local shopRows = {}
	for _, row in arena.shop do
		table.insert(shopRows, {
			`\`{row.key}\``,
			tostring(row.price),
			fmtValue(row.days, "1"),
			if row.gold then `{row.gold} zł` else "—",
		})
	end
	tableOut({ "pozycja sklepu areny", "cena (Żetony)", "dni (3 mecze dziennie)", "cena u kupca (złoto)" }, shopRows)
end

-- S129: the Blood Moon (F1) ----------------------------------------------------------------------------------------

do
	local bm = B.bloodMoon()
	local rules = ScheduledEvents.bloodMoon
	local reward = rules.reward
	local def = ScheduledEvents.get("bloodmoon") :: ScheduledEvents.EventDef
	local dayNames = { "pon.", "wt.", "śr.", "czw.", "pt.", "sob.", "niedz." }
	local slots = {}
	for _, slot in def.slots do
		table.insert(slots, `{dayNames[slot.weekday]} {string.format("%02d:%02d", slot.hour, slot.minute)} UTC`)
	end
	add("## Krwawy Księżyc (S129)")
	add()
	add(
		`Harmonogram (\`Data/ScheduledEvents\`): {table.concat(slots, ", ")}, {def.duration // 60} min, ogłoszenia {def.warn[1] // 60} min i {def.warn[2] // 60} min przed oraz na starcie; wydarzenia świata (S101) nie startują od {def.quietBefore // 60} min przed startem do końca. {bm.perWeek} razy w tygodniu.`
	)
	add()
	add(
		`Punkty: gracz {rules.points.player} (0, gdy ofiara ma {rules.levelGap} lub więcej poziomów mniej; ta sama ofiara najwyżej {rules.sameVictimMax} razy), Elita {rules.points.elite}, Elita II {rules.points.elite2}; śmierć 0. Nagrody (od {reward.minPoints} pkt): {reward.tokens} Żetonów Areny (poza limitem tygodnia, {fmtValue(bm.tokensShare * 100, "1")}% z {ArenaData.tokensWeekCap}) i Unikatowe błogosławieństwo (30 min); top {reward.titleTop} regionu tytuł na {reward.titleDays} dni, top {reward.frameTop} ramka, 1. miejsce {reward.shards} Smoczych Odłamków (tyle co najmniejsza paczka w sklepie, raz na region i wydarzenie). Bez asercji poza blokiem „Blood Moon (S129)” w \`balance.spec\`.`
	)
	add()
	add(
		`Elity w otwartych regionach (\`eliteChance\` = {rules.eliteChance}): każda zwykła grupa przy odrodzeniu wraca jako jedna Elita z tą szansą. Grupa bita od razu po odrodzeniu (górna granica):`
	)
	add()
	local rows = {}
	for _, row in bm.rows do
		table.insert(rows, {
			row.id,
			fmtValue(row.respawn, "1"),
			fmtValue(row.respawns, "1"),
			fmtValue(row.elites, "1"),
		})
	end
	tableOut({ "odrodzenie (profil łowiska)", "średnio s", "odrodzeń w 30 min", "Elit na grupę" }, rows)
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
	local hpMul = if (def :: any).hpMul then `HP ×{(def :: any).hpMul}, ` else ""
	add(`- {def.id} (L{def.level}): {hpMul}atak ×{def.atkMul}, ciosy {table.concat(attacks, ", ")}.`)
end
local stats: any = MonsterStats
if stats.kindReward then
	local hpExp, atkExp = (Combat :: any).kindRewardHpExponent, (Combat :: any).kindRewardAtkExponent
	add(
		`- EXP i złoto rodzaju × mnożnik HP^{hpExp} × (mnożnik ataku × szybkość)^{atkExp} × rewardMul rodzaju (S92, domyślnie 1).`
	)
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
