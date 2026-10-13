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
-- key -> the expected change (before = fixture, after = now) and why. S87: the Elites of spawners 19-20 (levels
-- 21-22) and Elite II of spawners 17-20 (21-24) get the curves above 20 (balance plan, S91 expects them).
local ALLOWED_1_20_DIFFS: { [string]: { before: number, after: number, why: string } } = {
	["Elity solo (poziom spawnera = poziom gracza, +2)|Cleric 20|HP"] = {
		before = 0.47457807992831935,
		after = 0.4956716967935514,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Elity solo (poziom spawnera = poziom gracza, +2)|Warrior 20|HP"] = {
		before = 0.5821320828465699,
		after = 0.6074625710043656,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Elity solo (poziom spawnera = poziom gracza, +2)|Hunter 20|HP"] = {
		before = 0.5880018406209372,
		after = 0.6132204101173754,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Elity solo (poziom spawnera = poziom gracza, +2)|Mage 20|HP"] = {
		before = 0.6713645470594916,
		after = 0.7000896371376419,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Drop: poziom przedmiotów i rzadkości|20|Heroiczne do klasy/h (Elity)"] = {
		before = 1.1460369491691362,
		after = 1.1027607023237767,
		why = "S87: longer Elite fights at level 22 (curves C5, C6) give fewer Elites per hour",
	},
	["Elity solo (poziom spawnera = poziom gracza, +2)|Mage 20|s"] = {
		before = 21.09524565727783,
		after = 21.747805308781963,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Elity solo (poziom spawnera = poziom gracza, +2)|Warrior 20|s"] = {
		before = 26.765076056459296,
		after = 27.593026059395577,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Elity solo (poziom spawnera = poziom gracza, +2)|Hunter 20|s"] = {
		before = 21.46274228724786,
		after = 22.12667006769812,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Elity solo (poziom spawnera = poziom gracza, +2)|Cleric 20|s"] = {
		before = 36.059619163959354,
		after = 37.17508626480759,
		why = "S87: Elite of spawner 20 is level 22, monster and Elite curves above 20 (C5, C6)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|caveSpider 18|solo HP"] = {
		before = 2.646735393422523,
		after = 2.7253656689289696,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|goblinShaman 18|solo HP"] = {
		before = 2.299272583078755,
		after = 2.367182099788169,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|caveSpider 18|2 graczy HP"] = {
		before = 1.1921630208543212,
		after = 1.2270247855357401,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|goblinShaman 18|2 graczy HP"] = {
		before = 1.0438007219497036,
		after = 1.073975355669151,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|caveSpider 18|3 graczy HP"] = {
		before = 0.7855250483194482,
		after = 0.8081509567186964,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|goblinShaman 18|3 graczy HP"] = {
		before = 0.6928229763166556,
		after = 0.7124485052942131,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|caveSpider 18|3 graczy s"] = {
		before = 22.83674749632847,
		after = 23.331885860870763,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|caveSpider 18|solo s"] = {
		before = 80.28992079756419,
		after = 82.03073875245586,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|caveSpider 18|2 graczy s"] = {
		before = 35.38913952895248,
		after = 36.15643446321321,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|goblinShaman 18|2 graczy s"] = {
		before = 31.456752990866203,
		after = 32.13749331364021,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|goblinShaman 18|solo s"] = {
		before = 71.36822877874442,
		after = 72.9126739765294,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
	["Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)|goblinShaman 18|3 graczy s"] = {
		before = 20.299163378049247,
		after = 20.738447719762068,
		why = "S87: Elite II of spawner 18 is level 22, monster curve above 20 (C5; elite2 curves neutral)",
	},
}

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
