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

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Balance = require("../tests/Balance")
local BalanceTables = require("../tests/BalanceTables")
local BudgetData = require("../src/shared/Data/QuestBudget")

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

return Gen
