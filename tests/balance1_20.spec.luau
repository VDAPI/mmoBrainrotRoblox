--!strict
-- Levels 1-20 against the fixture (S83, balance plan): tests/fixtures/balance_1_20.json holds every number of the
-- 1-20 report tables (tests/BalanceTables) from before the S91 retune. Until S91 the differences are only printed
-- (owner answer 4: 1-20 may be retuned); the structure is always checked: the file exists, no fixture key is gone
-- (a renamed table, row or column would hide a change) and no allowed difference is dead.
-- New fixture: `lune run tools/balance_report.luau fixture`. Full list of the differences: build/balance1_20_diff.txt.
-- Can be required from a small runner (no process.exit).

local fs = require("@lune/fs")

local BalanceTables = require("./BalanceTables")
local T = require("./Test")

local FIXTURE_ASSERT = false -- S91 re-asserts on its new fixture
local TOLERANCE = 0.005
-- key -> the expected change (before = fixture, after = now) and why; S91+ only.
local ALLOWED_1_20_DIFFS: { [string]: { before: number, after: number, why: string } } = {}

local OUT_DIR = "build"
local OUT = "build/balance1_20_diff.txt"

local report = BalanceTables.fixtureDiff(ALLOWED_1_20_DIFFS, TOLERANCE)
local before: { [string]: number } = (BalanceTables.readFixture() or {}).values or {}
local now = BalanceTables.values(BalanceTables.tables1_20(), true)

local function pct(rel: number, b: number, a: number): string
	return `{if a >= b then "+" else "-"}{string.format("%.1f", rel * 100)}%`
end

local lines = {}
for _, d in report.diffs do
	local mark = if d.allowed then " [dozwolona]" else ""
	table.insert(lines, `{d.key}: {d.before} → {d.after} ({pct(d.rel, d.before, d.after)}){mark}`)
end
for _, key in report.missing do
	table.insert(lines, `BRAK: {key}`)
end

print(
	`balance1_20: {#report.diffs} różnic ({#report.diffs - report.unexpected} dozwolonych), {#report.missing} brakujących kluczy, {report.added} nowych`
)
for i = 1, math.min(20, #report.diffs) do
	print(`  {lines[i]}`)
end
pcall(function()
	if not fs.isDir(OUT_DIR) then
		fs.writeDir(OUT_DIR)
	end
	fs.writeFile(OUT, table.concat(lines, "\n") .. "\n")
end)

T.describe("Balance 1-20 fixture (S83, report until S91)", function()
	T.it("the fixture exists and holds at least 1000 values", function()
		T.expect(report.found).toBe(true)
		T.expect(report.count >= 1000).toBe(true)
	end)

	T.it("every fixture key is still in the 1-20 tables", function()
		if #report.missing > 0 then
			error(
				`missing keys ({#report.missing}): {table.concat(report.missing, "; ", 1, math.min(10, #report.missing))}`,
				0
			)
		end
	end)

	T.it("no allowed difference is dead", function()
		for key, entry in ALLOWED_1_20_DIFFS do
			local b, a = before[key], now[key]
			if b == nil or a == nil then
				error(`ALLOWED_1_20_DIFFS: {key} is not in the fixture or the tables`, 0)
			end
			local rel = BalanceTables.relative
			if rel(a, b) <= TOLERANCE or rel(entry.before, b) > TOLERANCE or rel(entry.after, a) > TOLERANCE then
				error(`ALLOWED_1_20_DIFFS: {key} no longer matches ({b} → {a})`, 0)
			end
		end
	end)

	if FIXTURE_ASSERT then
		T.it("no difference outside ALLOWED_1_20_DIFFS", function()
			T.expect(report.unexpected).toBe(0)
		end)
	end
end)
