--!strict
-- Quest EXP budget generator (S98, docs/DESIGN-15.md §3.2): computes Data/QuestBudget.MONSTER_EXP_MUL from the quest
-- credit of the pace window model (tests/Balance.questCreditByLevel) against the kill shares of the S94 model frozen
-- in tests/fixtures/quest_budget_base.json. Pure apart from reading files; the CLI is tools/quest_budget.luau and
-- tests/questbudget.spec.luau checks the table with it. It knows no quest by name: every quest list comes from the
-- model's questSources (a new list = data with a `category`, never a change here).
--
-- Kill share of a level: s(L) = need(L) / expToNext(L) (need = EXP left after the quest credit and the carry).
-- monsterExpMul(L) = s(L) / s0(L) (1 when either is 0), clamped to [MUL_MIN, MUL_MAX], rounded to 0.001, so that
-- need / mul = s0 x expToNext: the hours of grinding per level stay those of the base.
-- S109: Gen.audit() (the final audit of the quest series, rows T-QB1..T-QB7 with Gen.AUDIT); the base file is the
-- permanent S94 reference and is never regenerated (Gen.baseAllowed).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Balance = require("../tests/Balance")
local BalanceTables = require("../tests/BalanceTables")
local BudgetData = require("../src/shared/Data/QuestBudget")
local QuestBudget = require("../src/shared/Logic/QuestBudget")
local Quests = require("../src/shared/Data/Quests")

local Gen = {}

Gen.BASE_PATH = "tests/fixtures/quest_budget_base.json"
Gen.DATA_PATH = "src/shared/Data/QuestBudget.luau"
Gen.BEGIN = "-- BEGIN GENERATED (lune run tools/quest_budget.luau)"
Gen.END = "-- END GENERATED"
Gen.LEVELS = 99
Gen.CATEGORIES = { "main", "side", "boss", "contract" }
-- the tolerance of tests/balance1_20.spec (BalanceTables.FIXTURE_TOLERANCE)
Gen.TOLERANCE = BalanceTables.FIXTURE_TOLERANCE

export type Row = {
	exp: number,
	quest: number,
	carryIn: number,
	need: number,
	share: number,
	byCategory: { [string]: number }?,
}
export type Computed = {
	mul: { number },
	rows: { { level: number, s0: number, s: number, raw: number, mul: number } },
	clamped: { number },
}

local function round3(x: number): number
	return math.floor(x * 1000 + 0.5) / 1000
end

local function toRow(r: any): Row
	return {
		exp = r.exp,
		quest = r.quest,
		carryIn = r.carryIn,
		need = r.need,
		share = if r.exp > 0 then r.need / r.exp else 0,
		byCategory = r.byCategory,
	}
end

-- The current quest credit per level 1..99 (opts.budget = false: the S94 model of the base).
function Gen.credit(opts: { budget: boolean? }?): { [number]: Row }
	local rows = Balance.questCreditByLevel({ budget = if opts and opts.budget == false then false else true })
	local out: { [number]: Row } = {}
	for L = 1, Gen.LEVELS do
		out[L] = toRow(rows[L])
	end
	return out
end

-- The frozen base (tests/fixtures/quest_budget_base.json) as rows 1..99.
function Gen.base(): { [number]: Row }
	if not fs.isFile(Gen.BASE_PATH) then
		error(`{Gen.BASE_PATH} is missing: run \`lune run tools/quest_budget.luau base\``, 0)
	end
	local file = serde.decode("json", fs.readFile(Gen.BASE_PATH))
	local out: { [number]: Row } = {}
	for L = 1, Gen.LEVELS do
		local r = file.levels[tostring(L)]
		assert(r, `{Gen.BASE_PATH}: no level {L}`)
		out[L] = { exp = r.exp, quest = r.quest, carryIn = r.carryIn, need = r.need, share = r.share }
	end
	return out
end

-- The base file content for the S94 model (Balance.questCreditByLevel({ budget = false })).
function Gen.baseFile(session: string, commit: string, date: string): any
	local levels = {}
	for L, r in Gen.credit({ budget = false }) do
		levels[tostring(L)] = { exp = r.exp, quest = r.quest, carryIn = r.carryIn, need = r.need, share = r.share }
	end
	return {
		meta = {
			session = session,
			commit = commit,
			date = date,
			note = "kill share per level of the S94 pace model; the quest budget compensation keeps it",
		},
		levels = levels,
	}
end

-- The multipliers for the current quest data (opts.budget = false: the base model itself, all 1.000).
function Gen.compute(opts: { budget: boolean? }?): Computed
	local base = Gen.base()
	local now = Gen.credit(opts)
	local mul: { number } = {}
	local rows = {}
	local clamped: { number } = {}
	for L = 1, Gen.LEVELS do
		local s0, s = base[L].share, now[L].share
		local raw = if s0 > 0 and s > 0 then s / s0 else 1
		if s0 > 0 and s <= 0 then
			-- the quests cover the whole level now: nothing left to compensate on it
			table.insert(clamped, L)
		end
		local m = math.clamp(raw, BudgetData.MUL_MIN, BudgetData.MUL_MAX)
		if m ~= raw then
			table.insert(clamped, L)
		end
		mul[L] = round3(m)
		table.insert(rows, { level = L, s0 = s0, s = s, raw = raw, mul = mul[L] })
	end
	return { mul = mul, rows = rows, clamped = clamped }
end

-- The numbers of the current data file.
function Gen.read(): { number }
	local out: { number } = {}
	for L = 1, Gen.LEVELS do
		out[L] = BudgetData.MONSTER_EXP_MUL[L]
	end
	return out
end

-- The Luau block between the GENERATED markers (10 numbers a row, `-- stylua: ignore` keeps the rows).
function Gen.render(mul: { number }): string
	local lines = {
		Gen.BEGIN,
		"-- stylua: ignore",
		"local MONSTER_EXP_MUL = table.freeze({ -- index = character level 1-99",
	}
	for i = 1, #mul, 10 do
		local row = {}
		for j = i, math.min(i + 9, #mul) do
			table.insert(row, string.format("%.3f", mul[j]))
		end
		table.insert(lines, "\t" .. table.concat(row, ", ") .. ",")
	end
	table.insert(lines, "})")
	table.insert(lines, Gen.END)
	return table.concat(lines, "\n")
end

-- `source` with the block between the markers replaced (error without the markers).
function Gen.replaceBlock(source: string, block: string): string
	local a = string.find(source, Gen.BEGIN, 1, true)
	local b0, b1 = string.find(source, Gen.END, a or 1, true)
	if not a or not b0 or not b1 then
		error(`{Gen.DATA_PATH}: the GENERATED markers are missing`, 0)
	end
	return string.sub(source, 1, a - 1) .. block .. string.sub(source, b1 + 1)
end

-- Levels whose multiplier differs (by more than 0.0005) between `a` and `b`.
function Gen.diff(a: { number }, b: { number }): { number }
	local out: { number } = {}
	for L = 1, Gen.LEVELS do
		if math.abs((a[L] or 0) - (b[L] or 0)) > 0.0005 then
			table.insert(out, L)
		end
	end
	return out
end

-- Quest EXP share per band and category: the category's credited EXP / sum of expToNext over the band.
-- `full` = every side quest in full (a player who does everything) instead of the model's SIDE_SHARE.
function Gen.shares(full: boolean?): { { lo: number, hi: number, byCategory: { [string]: number }, total: number } }
	local credit = Gen.credit()
	local out = {}
	for _, band in BudgetData.BANDS do
		local lo, hi = band[1], band[2]
		local sumE = 0
		local by: { [string]: number } = {}
		for L = lo, hi do
			sumE += credit[L].exp
			for cat, v in credit[L].byCategory or {} do
				local value = if full and cat == "side" then v / Balance.SIDE_SHARE else v
				by[cat] = (by[cat] or 0) + value
			end
		end
		local total = 0
		for cat, v in by do
			by[cat] = v / sumE
			total += by[cat]
		end
		table.insert(out, { lo = lo, hi = hi, byCategory = by, total = total })
	end
	return out
end

-- Hours of grinding per band in EXP units: base = sum s0 x E, now = sum need / mul (the current table).
function Gen.grind(mul: { number }?): { { lo: number, hi: number, base: number, now: number } }
	local m = mul or Gen.read()
	local base = Gen.base()
	local credit = Gen.credit()
	local out = {}
	for _, band in BudgetData.BANDS do
		local b, n = 0, 0
		for L = band[1], band[2] do
			b += base[L].share * credit[L].exp
			n += credit[L].need / m[L]
		end
		table.insert(out, { lo = band[1], hi = band[2], base = b, now = n })
	end
	return out
end

export type AllowedLine = { key: string, before: number, after: number, why: string }
export type AllowedReport = {
	entries: { AllowedLine }, -- every difference against the 1-20 fixture, sorted by key
	added: { string }, -- differences without an entry in BalanceTables.ALLOWED_1_20_DIFFS
	changed: { string }, -- entries whose before / after no longer match
	dead: { string }, -- entries without a difference
	text: string, -- the block to paste into BalanceTables.ALLOWED_1_20_DIFFS
}

local function num(x: number): string
	local s = string.format("%.10g", x)
	return s
end

-- The ALLOWED_1_20_DIFFS block for the current data (S99+ H4: an existing key keeps its `why` and gets "; <why>"
-- appended once; no duplicated keys). Writes nothing.
function Gen.allowed(why: string): AllowedReport
	local existing = BalanceTables.ALLOWED_1_20_DIFFS
	local report = BalanceTables.fixtureDiff(nil, Gen.TOLERANCE)
	local rel = BalanceTables.relative
	local entries: { AllowedLine } = {}
	local added, changed, dead = {}, {}, {}
	local seen: { [string]: boolean } = {}
	for _, d in report.diffs do
		seen[d.key] = true
		local old = existing[d.key]
		local text = why
		if old then
			text = old.why
			if rel(old.before, d.before) > Gen.TOLERANCE or rel(old.after, d.after) > Gen.TOLERANCE then
				table.insert(changed, d.key)
				if not string.find(text, why, 1, true) then
					text ..= "; " .. why
				end
			end
		else
			table.insert(added, d.key)
		end
		table.insert(entries, { key = d.key, before = d.before, after = d.after, why = text })
	end
	for key in existing do
		if not seen[key] then
			table.insert(dead, key)
		end
	end
	table.sort(entries, function(x, y)
		return x.key < y.key
	end)
	table.sort(added)
	table.sort(changed)
	table.sort(dead)
	local lines = {}
	for _, e in entries do
		table.insert(
			lines,
			`\t[{string.format("%q", e.key)}] = \{ before = {num(e.before)}, after = {num(e.after)}, why = {string.format(
				"%q",
				e.why
			)} \},`
		)
	end
	return { entries = entries, added = added, changed = changed, dead = dead, text = table.concat(lines, "\n") }
end

-- The session of a regeneration: `flag` ("S<n>") or the last "### S<n>" of docs/SESJE.md + 1.
function Gen.session(flag: string?): string
	if flag then
		return flag
	end
	local last = 0
	if fs.isFile("docs/SESJE.md") then
		for n in string.gmatch(fs.readFile("docs/SESJE.md"), "\n### S(%d+)") do
			last = math.max(last, tonumber(n) or 0)
		end
	end
	return `S{last + 1}`
end

-- Quest budget audit (S109, docs/DESIGN-15.md §3.2) ------------------------------------------------------------------
-- The final audit of the quest series S98-S108: the share of a level's EXP the one-time quests give (TARGET, ~30%),
-- the compensation (monsterExpMul) and the hours of grinding per level against the S94 base. Pure (reads the data and
-- the base file); tests/questbudget.spec.luau asserts the rows, `lune run tools/quest_budget.luau audit` prints them
-- and tools/balance_report.luau writes them into docs/BALANS.md ("Audyt questów (S109)"). One source of truth: `rows`.

-- The audit targets: measuring tools, not game numbers (like the S87 targets G1-G13 in the tests).
Gen.AUDIT = table.freeze({
	-- TARGET sums to 0.30; +-10% on the total holds the rounding and the rhythm of the quests (T-QB1)
	total = { 0.27, 0.33 },
	-- the contract is a formula (TARGET.contract x expToNext), so its band is narrow (T-QB2, T-QB4)
	contract = { 0.105, 0.125 },
	-- the story (S102 settleStory) and the side quests (S106 settleBands) are a band share by construction, rounded
	-- down: any shortfall beyond 0.003 is a data error (a quest outside its band, an arc counted twice) (T-QB2)
	below = 0.003,
	-- boss quests depend on the number of bosses of the band: +-25% (T-QB2)
	boss = { 0.015, 0.025 },
	-- the asserted bands (1-19 is the frozen Meadows, T-QB4)
	bands = { { 20, 44 }, { 45, 69 }, { 70, 99 } },
	-- T-QB3: the centred moving mean of the `all` total over `window` levels (clipped at the band's edges), L 21..97
	window = 5,
	moving = { 0.15, 0.50 },
	movingLevels = { 21, 97 },
	-- T-QB5: no level clamped; monsterExpMul on 20..99 in `mul`; a step between neighbours of one band <= `jump`
	mul = { 0.55, 1.00 },
	mulFrom = 20,
	jump = 0.10,
	-- T-QB6: hours of grinding now / base, per band (like S98) and per level
	grindBand = { 0.99, 1.01 },
	grindLevel = { 0.97, 1.03 },
	-- the report rows (rule 5 of the session: the closest result, the reason, a line in DECYZJE)
	report = {
		-- S109: Meadows 1–19 above 30% by design (tutorial S32, side arcs S27, frozen 1–20)
		["T-QB4.main"] = "Meadows 1–19 above 30% by design (tutorial S32, side arcs S27, frozen 1–20)",
		["T-QB4.side"] = "Meadows 1–19 above 30% by design (tutorial S32, side arcs S27, frozen 1–20)",
		["T-QB4.total"] = "Meadows 1–19 above 30% by design (tutorial S32, side arcs S27, frozen 1–20)",
		-- S109: T-QB5 max 1.00 on 20-44 poza zasięgiem dźwigni S109: the S94 story gave 27.5% of the band (60% of
		-- level 20, 52% of 21-23), the quests now 27.0%, so the compensation is >= 1 on average; T-QB3 (<= 0.50 on
		-- 21) keeps the story of 20-23 below the S94 one: 1.23 on 20, 1.15 on 21-23
		["T-QB5.max.20"] = "poza zasięgiem dźwigni S109: zadania dają w modelu 27,0% pasma 20–44 wobec 27,5% fabuły S94 (60% poziomu 20, 52% 21–23), więc kompensacja jest średnio ≥ 1; T-QB3 trzyma fabułę 20–23 poniżej S94 (1,23 na 20, 1,15 na 21–23)",
	} :: { [string]: string },
})

export type AuditShares = { byCategory: { [string]: number }, total: number }
export type AuditBand = { lo: number, hi: number, model: AuditShares, all: AuditShares }
export type AuditLevel = {
	level: number,
	exp: number,
	all: { [string]: number }, -- share of expToNext per category, every side quest in full (credit distribution)
	total: number,
	avg: number, -- the moving mean of `total` (AUDIT.window, clipped at the band's edges)
	s0: number,
	s: number,
	mul: number,
	clamped: boolean,
	hoursBase: number, -- hours of grinding of the S94 model (s0 x expToNext / EXP per hour without the multiplier)
	hoursNow: number, -- need / (mul x EXP per hour), the pace window model
	noQuests: number, -- the whole level from monsters with the multiplier
	noQuestsS94: number, -- the whole level from monsters without it (a player without quests in S94)
	allQuests: number, -- every quest in full (side quests too)
	allExtras: number, -- every quest and the extras of Balance.PLAY_PROFILE
}
export type AuditHours = {
	lo: number,
	hi: number, -- the band from `lo` to `hi` (levels lo .. hi - 1)
	s94: number,
	now: number, -- Balance.paceWindowAt("Warrior", L).hours (the model of the S91-S94 targets)
	noQuests: number,
	noQuestsS94: number,
	allQuests: number,
	allExtras: number,
}
export type AuditRow = {
	id: string,
	label: string,
	value: number,
	band: { lo: number?, hi: number? },
	ok: boolean,
	report: boolean,
	why: string?,
	outliers: { string },
}
export type Audit = {
	bands: { AuditBand },
	levels: { AuditLevel },
	hours: { AuditHours },
	rows: { AuditRow },
	skipped: { string }, -- main quests the model leaves out (a boss objective: the chapter finales)
}

local function hasBoss(q: any): boolean
	for _, o in q.objectives do
		if o.type == "boss" then
			return true
		end
	end
	return false
end

local function bandIndex(L: number): (number, number)
	local lo, hi = QuestBudget.bandOf(L)
	return lo, hi
end

-- `all` band shares by the quests' own level: the story without the boss objectives (S102 settleStory), every side
-- quest in full (S106 settleBands), the boss quests, the contracts.
local function allBands(): { [number]: AuditShares }
	local sums: { [number]: { [string]: number } } = {}
	for _, source in Balance.questSourceLists(true) do
		for _, q in source.list do
			local category: string = q.category or "main"
			if q.level < 100 and not (category == "main" and hasBoss(q)) then
				local lo = bandIndex(q.level)
				local by = sums[lo] or {}
				sums[lo] = by
				by[category] = (by[category] or 0) + (q.reward.exp or 0)
			end
		end
	end
	local out: { [number]: AuditShares } = {}
	for _, band in BudgetData.BANDS do
		local e = QuestBudget.bandExp(band[1])
		local by: { [string]: number } = {}
		local total = 0
		for cat, v in sums[band[1]] or {} do
			by[cat] = v / e
			total += v / e
		end
		out[band[1]] = { byCategory = by, total = total }
	end
	return out
end

local auditCache: Audit? = nil

-- The audit of the current data (cached: the data do not change during a run; `fresh` recomputes it, the test of
-- determinism compares two computations).
function Gen.audit(fresh: boolean?): Audit
	if auditCache and not fresh then
		return auditCache
	end
	local A = Gen.AUDIT
	local computed = Gen.compute()
	local clampedSet: { [number]: boolean } = {}
	for _, L in computed.clamped do
		clampedSet[L] = true
	end
	local base = Gen.base()
	local credit = Gen.credit()
	local mul = Gen.read()
	-- bands
	local model = Gen.shares(false)
	local all = allBands()
	local bands: { AuditBand } = {}
	for i, band in BudgetData.BANDS do
		local m = model[i]
		table.insert(bands, {
			lo = band[1],
			hi = band[2],
			model = { byCategory = m.byCategory, total = m.total },
			all = all[band[1]],
		})
	end
	-- levels: the `all` credit (side quests in full) with its own carry, the hours
	local levels: { AuditLevel } = {}
	local carry = 0
	for L = 1, Gen.LEVELS do
		local row = credit[L]
		local by = row.byCategory or {}
		local shares: { [string]: number } = {}
		local quest = 0
		for _, cat in Gen.CATEGORIES do
			local v = by[cat] or 0
			if cat == "side" then
				v /= Balance.SIDE_SHARE
			end
			shares[cat] = v / row.exp
			quest += v
		end
		local needAll = math.max(0, row.exp - quest - carry)
		carry = math.max(0, quest + carry - row.exp)
		local pw = Balance.paceWindowAt("Warrior", L)
		local perHour = pw.expPerKill * 3600 / pw.secondsPerKill -- with the multiplier
		local xph = perHour / mul[L] -- without it
		local extras = Balance.extrasExpPerHour(L).total
		local total = 0
		for _, v in shares do
			total += v
		end
		table.insert(levels, {
			level = L,
			exp = row.exp,
			all = shares,
			total = total,
			avg = 0,
			s0 = base[L].share,
			s = row.share,
			mul = mul[L],
			clamped = clampedSet[L] == true,
			hoursBase = base[L].share * row.exp / xph,
			hoursNow = pw.hours,
			noQuests = row.exp / perHour,
			noQuestsS94 = row.exp / xph,
			allQuests = needAll / perHour,
			allExtras = needAll / (perHour + extras),
		})
	end
	for _, lv in levels do
		local lo, hi = bandIndex(lv.level)
		local half = math.floor(A.window / 2)
		local sum, n = 0, 0
		for k = math.max(lo, lv.level - half), math.min(hi, lv.level + half) do
			sum += levels[k].total
			n += 1
		end
		lv.avg = sum / n
	end
	-- hours per band (the S91-S94 bands: lo .. hi - 1)
	local hours: { AuditHours } = {}
	for _, band in { { 1, 20 }, { 20, 45 }, { 45, 70 }, { 70, 100 }, { 1, 100 } } do
		local h: AuditHours = {
			lo = band[1],
			hi = band[2],
			s94 = 0,
			now = 0,
			noQuests = 0,
			noQuestsS94 = 0,
			allQuests = 0,
			allExtras = 0,
		}
		for L = band[1], band[2] - 1 do
			local lv = levels[L]
			h.s94 += lv.hoursBase
			h.now += lv.hoursNow
			h.noQuests += lv.noQuests
			h.noQuestsS94 += lv.noQuestsS94
			h.allQuests += lv.allQuests
			h.allExtras += lv.allExtras
		end
		table.insert(hours, h)
	end
	-- rows
	local rows: { AuditRow } = {}
	local function row(id: string, label: string, value: number, lo: number?, hi: number?, outliers: { string }?)
		local ok = (lo == nil or value >= lo - 1e-9) and (hi == nil or value <= hi + 1e-9)
		local why = A.report[id]
		table.insert(rows, {
			id = id,
			label = label,
			value = value,
			band = { lo = lo, hi = hi },
			ok = ok and (outliers == nil or #outliers == 0),
			report = why ~= nil,
			why = why,
			outliers = outliers or {},
		})
	end
	local byLo: { [number]: AuditBand } = {}
	for _, b in bands do
		byLo[b.lo] = b
	end
	for _, band in A.bands do
		local b = byLo[band[1]]
		row(`T-QB1.{band[1]}`, `zadania razem (all), {band[1]}–{band[2]}`, b.all.total, A.total[1], A.total[2])
	end
	for _, band in A.bands do
		local b = byLo[band[1]]
		local by = b.all.byCategory
		local tag = `{band[1]}–{band[2]}`
		row(`T-QB2.contract.{band[1]}`, `zlecenia (all), {tag}`, by.contract or 0, A.contract[1], A.contract[2])
		local main, side = BudgetData.TARGET.main, BudgetData.TARGET.side
		row(`T-QB2.main.{band[1]}`, `fabuła (all, bez celu boss), {tag}`, by.main or 0, main - A.below, main)
		row(`T-QB2.side.{band[1]}`, `poboczne (all), {tag}`, by.side or 0, side - A.below, side)
		row(`T-QB2.boss.{band[1]}`, `bossowe (all), {tag}`, by.boss or 0, A.boss[1], A.boss[2])
	end
	do
		local high, low = { value = -math.huge, out = {} }, { value = math.huge, out = {} }
		for L = A.movingLevels[1], A.movingLevels[2] do
			local v = levels[L].avg
			high.value = math.max(high.value, v)
			low.value = math.min(low.value, v)
			if v > A.moving[2] then
				table.insert(high.out, `L{L} {string.format("%.3f", v)}`)
			end
			if v < A.moving[1] then
				table.insert(low.out, `L{L} {string.format("%.3f", v)}`)
			end
		end
		local span = `{A.movingLevels[1]}–{A.movingLevels[2]}`
		row(
			"T-QB3.max",
			`średnia krocząca ({A.window}) udziału all, najwyższa na {span}`,
			high.value,
			nil,
			A.moving[2],
			high.out
		)
		row(
			"T-QB3.min",
			`średnia krocząca ({A.window}) udziału all, najniższa na {span}`,
			low.value,
			A.moving[1],
			nil,
			low.out
		)
	end
	do
		local b = byLo[1]
		local by = b.all.byCategory
		row("T-QB4.contract", "zlecenia (all), 1–19", by.contract or 0, A.contract[1], A.contract[2])
		row("T-QB4.main", "fabuła (all, bez celu boss), 1–19", by.main or 0, nil, BudgetData.TARGET.main)
		row("T-QB4.side", "poboczne (all), 1–19", by.side or 0, nil, BudgetData.TARGET.side)
		row("T-QB4.total", "zadania razem (all), 1–19", b.all.total, A.total[1], A.total[2])
	end
	do
		local clampedOut = {}
		for _, L in computed.clamped do
			table.insert(clampedOut, `L{L}`)
		end
		row("T-QB5.clamped", "poziomy przycięte do MUL_MIN / MUL_MAX (1–99)", #computed.clamped, 0, 0, clampedOut)
		local function range(id: string, label: string, from: number, to: number, useMax: boolean)
			local value = if useMax then -math.huge else math.huge
			local out = {}
			for L = from, to do
				local m = mul[L]
				value = if useMax then math.max(value, m) else math.min(value, m)
				if (useMax and m > A.mul[2] + 1e-9) or (not useMax and m < A.mul[1] - 1e-9) then
					table.insert(out, `L{L} {string.format("%.3f", m)}`)
				end
			end
			row(id, label, value, if useMax then nil else A.mul[1], if useMax then A.mul[2] else nil, out)
		end
		range("T-QB5.min", `monsterExpMul najniższy, {A.mulFrom}–99`, A.mulFrom, 99, false)
		range("T-QB5.max.20", "monsterExpMul najwyższy, 20–44", 20, 44, true)
		range("T-QB5.max.45", "monsterExpMul najwyższy, 45–99", 45, 99, true)
		local worst, out = 0, {}
		for L = A.mulFrom + 1, 99 do
			if bandIndex(L) == bandIndex(L - 1) then
				local d = math.abs(mul[L] - mul[L - 1])
				worst = math.max(worst, d)
				if d > A.jump + 1e-9 then
					table.insert(out, `L{L - 1}→{L} {string.format("%.3f", d)}`)
				end
			end
		end
		row("T-QB5.jump", `największy skok monsterExpMul w paśmie (od {A.mulFrom})`, worst, nil, A.jump, out)
	end
	do
		local lowB, highB, outB = math.huge, -math.huge, {}
		for _, band in BudgetData.BANDS do
			local b, n = 0, 0
			for L = band[1], band[2] do
				b += levels[L].hoursBase
				n += levels[L].hoursNow
			end
			local r = if b > 0 then n / b else 1
			lowB, highB = math.min(lowB, r), math.max(highB, r)
			if r < A.grindBand[1] or r > A.grindBand[2] then
				table.insert(outB, `{band[1]}–{band[2]} {string.format("%.4f", r)}`)
			end
		end
		local lowL, highL, outL = math.huge, -math.huge, {}
		for L = 1, Gen.LEVELS do
			local lv = levels[L]
			if lv.hoursBase > 1e-9 then
				local r = lv.hoursNow / lv.hoursBase
				lowL, highL = math.min(lowL, r), math.max(highL, r)
				if r < A.grindLevel[1] or r > A.grindLevel[2] then
					table.insert(outL, `L{L} {string.format("%.4f", r)}`)
				end
			end
		end
		local farB = if math.abs(lowB - 1) > math.abs(highB - 1) then lowB else highB
		local farL = if math.abs(lowL - 1) > math.abs(highL - 1) then lowL else highL
		row(
			"T-QB6.band",
			"godziny bicia teraz / baza S94, pasmo (najdalej od 1)",
			farB,
			A.grindBand[1],
			A.grindBand[2],
			outB
		)
		row(
			"T-QB6.level",
			"godziny bicia teraz / baza S94, poziom (najdalej od 1)",
			farL,
			A.grindLevel[1],
			A.grindLevel[2],
			outL
		)
	end
	local skipped = {}
	do
		local problems = {}
		local seen: { [string]: number } = {}
		for _, source in Balance.questSourceLists(true) do
			for _, q in source.list do
				seen[q.id] = (seen[q.id] or 0) + 1
				if Balance.CREDIT_RULES[q.category or ""] == nil then
					table.insert(problems, `{q.id}: category {q.category}`)
				end
				if (q.category or "main") == "main" and hasBoss(q) then
					table.insert(skipped, q.id)
				end
			end
		end
		for _, list in { Quests.Main.list, Quests.Side.list, Quests.Boss.list, Quests.Contracts.list } do
			for _, q in list :: { any } do
				if seen[q.id] ~= 1 then
					table.insert(problems, `{q.id}: seen {seen[q.id] or 0}x`)
				end
				if q.category == nil then
					table.insert(problems, `{q.id}: no category`)
				end
			end
		end
		for L = 1, Quests.Contracts.MAX_LEVEL do
			local c = Quests.Contracts.byLevel[L]
			if not c or c.level ~= L then
				table.insert(problems, `contract_{L}: missing`)
			end
		end
		row(
			"T-QB7",
			"kompletność: zadania widziane przez credit() dokładnie raz, zlecenia 1–99 bez dziur",
			#problems,
			0,
			0,
			problems
		)
	end
	auditCache = { bands = bands, levels = levels, hours = hours, rows = rows, skipped = skipped }
	return auditCache :: Audit
end

local function fmtNumber(id: string, value: number): string
	if string.sub(id, 1, 5) == "T-QB5" and id ~= "T-QB5.clamped" or string.sub(id, 1, 5) == "T-QB6" then
		return string.format("%.3f", value)
	elseif id == "T-QB5.clamped" or id == "T-QB7" then
		return tostring(value)
	end
	return string.format("%.1f%%", value * 100)
end
Gen.fmtAuditValue = fmtNumber

-- The band of a row as text ("0.27–0.33", "≤ 0.50", "≥ 0.55").
function Gen.fmtAuditBand(r: AuditRow): string
	local lo = if r.band.lo then fmtNumber(r.id, r.band.lo) else nil
	local hi = if r.band.hi then fmtNumber(r.id, r.band.hi) else nil
	if lo and hi then
		return if lo == hi then lo else `{lo}–{hi}`
	end
	return if lo then `≥ {lo}` else `≤ {hi or "?"}`
end

-- The result word of a row: OK, POZA (an asserted row outside its target) or "raport".
function Gen.auditVerdict(r: AuditRow): string
	if r.report then
		return if r.ok then "raport (OK)" else "raport"
	end
	return if r.ok then "OK" else "POZA"
end

-- The text the CLI prints (`audit`, `report`): the bands of both variants, the T-QB rows, the outliers.
function Gen.auditText(a: Audit): string
	local lines = {}
	local function pct(x: number): string
		return string.format("%.1f%%", x * 100)
	end
	for _, variant in { "model", "all" } do
		table.insert(lines, `Quest EXP share per band ({variant}):`)
		for _, b in a.bands do
			local shares = (b :: any)[variant] :: AuditShares
			local parts = {}
			for _, cat in Gen.CATEGORIES do
				table.insert(parts, `{cat} {pct(shares.byCategory[cat] or 0)}`)
			end
			table.insert(lines, `  {b.lo}-{b.hi}: {table.concat(parts, ", ")}, total {pct(shares.total)}`)
		end
	end
	table.insert(lines, "Audit rows (S109):")
	for _, r in a.rows do
		local text = `  {r.id} {r.label}: {fmtNumber(r.id, r.value)} (cel {Gen.fmtAuditBand(r)}) {Gen.auditVerdict(r)}`
		if #r.outliers > 0 then
			text ..= ` [{table.concat(r.outliers, ", ", 1, math.min(12, #r.outliers))}]`
		end
		table.insert(lines, text)
	end
	table.insert(lines, "Hours (Warrior, pace window model):")
	for _, h in a.hours do
		table.insert(
			lines,
			string.format(
				"  %d->%d: S94 %.1f h, now %.1f h, no quests %.1f h (S94 %.1f h), all quests %.1f h, all + extras %.1f h",
				h.lo,
				h.hi,
				h.s94,
				h.now,
				h.noQuests,
				h.noQuestsS94,
				h.allQuests,
				h.allExtras
			)
		)
	end
	return table.concat(lines, "\n")
end

-- True when every asserted row (report = false) is in its target.
function Gen.auditOk(a: Audit): boolean
	for _, r in a.rows do
		if not r.report and not r.ok then
			return false
		end
	end
	return true
end

-- S109 (D4): the S98 base is the permanent S94 reference; `base` never overwrites it, not even with --force.
Gen.BASE_REFUSAL = "the S98 base is the permanent S94 reference (S109, DECYZJE)"
function Gen.baseAllowed(exists: boolean, _force: boolean): (boolean, string?)
	if exists then
		return false, Gen.BASE_REFUSAL
	end
	return true, nil
end

return Gen
