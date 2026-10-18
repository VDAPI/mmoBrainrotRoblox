--!strict
-- Levels 1-20 against the fixture (S83, balance plan): tests/fixtures/balance_1_20.json holds every number of the
-- 1-20 report tables (tests/BalanceTables) after the S91 retune (with the L20 anchor of the skill layer). S91: strict,
-- every difference above TOLERANCE outside BalanceTables.ALLOWED_1_20_DIFFS fails; the structure is always checked: the file
-- exists, no fixture key is gone (a renamed table, row or column would hide a change) and no allowed difference is
-- dead. Rows that depend on S92's data (fights with monsters above level 20, the window pace at 20) are not in the
-- fixture (`fixture = false`) and are asserted by balance.spec.
-- New fixture: `lune run tools/balance_report.luau fixture S<n> "<note>"` (only on the owner's decision; S109: the
-- 1-20 baseline after the quest series S95-S109, DESIGN-15 §0.4; last S134: bosses 2.0, only the Grimrok sections
-- moved; S134i: the Meadows' Elite II hideouts, new rows only; S140: the Mage's fire pool, Mage keys only; S141: the
-- Mage's ice pool, Mage keys only; S142: the Mage's lightning pool, Mage keys and Grimrok's parties without
-- support; S143: the Warrior's pools, Warrior keys and the rows holding a Warrior; S144: the Hunter's pools, Hunter keys
-- and the rows holding a Hunter). Full list of the differences: build/balance1_20_diff.txt.
-- Can be required from a small runner (no process.exit).

local fs = require("@lune/fs")

local BalanceTables = require("./BalanceTables")
local T = require("./Test")

local TOLERANCE = 0.005
-- S91: levels 1-20 frozen; every future difference is an entry in BalanceTables.ALLOWED_1_20_DIFFS and a DECYZJE
-- line (G12 in balance.spec reads the same list).
local ALLOWED_1_20_DIFFS = BalanceTables.ALLOWED_1_20_DIFFS

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

T.describe("Balance 1-20 fixture (S83; strict from S91)", function()
	T.it("the fixture exists and holds at least 1000 values", function()
		T.expect(report.found).toBe(true)
		T.expect(report.count >= 1000).toBe(true)
	end)

	-- S134h: the new baseline (Elite II rows only: the second Elite IIs of the Meadows' caves, the Elite II loot per kill)
	-- S134i: the new baseline (new Elite II rows only: the Meadows' hideouts; no other key moved)
	-- S140 (DESIGN-18 §0.3): the new baseline in the Mage's keys only (the fire pool, the common skills, the directions'
	-- nodes; with Grimrok's parties without support, which hold two Mage builds); docs/DECYZJE.md S140
	-- S141: the new baseline in the Mage's keys only (the ice pool: 105 changed, 44 new rows of the ice variants)
	-- S142: the lightning pool and the end of the transitional Mage (173 changed, 44 new rows of the lightning variants;
	-- 6 of the changed are Grimrok's parties without support, which hold two Mage builds); docs/DECYZJE.md S142
	-- S143: the Warrior's two pools (Sword and Shield, Two-Handed), the common skills and the directions' nodes: 413
	-- changed and 30 new rows, all in the Warrior's keys or in rows that hold a Warrior (Grimrok's parties, the S32
	-- melee trio of the Elite II caves and hideouts, the Healer on the Defender); docs/DECYZJE.md S143
	-- S144: the Hunter's two pools (Bow, Crossbow), the common skills and the directions' nodes: 417 changed rows, all
	-- in the Hunter's keys or in rows that hold a Hunter (Grimrok's parties, the W + M + Ł + K parties of the Elite IIs of
	-- the Meadows' caves and hideouts); docs/DECYZJE.md S144
	T.it("the fixture is the S144 baseline (the Hunter's pools)", function()
		local file = BalanceTables.readFixture()
		T.expect(file and file.meta and file.meta.session).toBe("S144")
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

	T.it("no difference outside ALLOWED_1_20_DIFFS", function()
		if report.unexpected > 0 then
			local shown = {}
			for _, d in report.diffs do
				if not d.allowed and #shown < 5 then
					table.insert(shown, `{d.key}: {d.before} → {d.after}`)
				end
			end
			error(
				`{report.unexpected} difference(s) against tests/fixtures/balance_1_20.json (1-20 frozen by S91; add `
					.. `ALLOWED_1_20_DIFFS and a DECYZJE line): {table.concat(shown, "; ")}`,
				0
			)
		end
	end)
end)
