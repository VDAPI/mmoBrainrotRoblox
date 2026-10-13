--!strict
-- Quest EXP budget (S98, docs/DESIGN-15.md §3.2). Run from the repo root after every change of the quest data:
--   lune run tools/quest_budget.luau            recomputes Data/QuestBudget.MONSTER_EXP_MUL (only the GENERATED block)
--                                               and prints the line for tools/balance_reasons.luau
--   lune run tools/quest_budget.luau check      exit 1 when the table is out of date (= tests/questbudget.spec)
--   lune run tools/quest_budget.luau report     prints only
--   lune run tools/quest_budget.luau allowed --why "S<n>: <what came>"   the ALLOWED_1_20_DIFFS block to paste
--   lune run tools/quest_budget.luau base [--force]   writes tests/fixtures/quest_budget_base.json (S98; only the
--                                               final audit S109 may rebase it with --force)
--   --session S<n>   the session of the printed ledger line (default: the last "### S<n>" of docs/SESJE.md + 1)
-- Logic in tools/QuestBudgetGen.luau.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local BudgetData = require("../src/shared/Data/QuestBudget")
local Gen = require("./QuestBudgetGen")

local args = process.args
local mode = "write"
local sessionFlag: string? = nil
local why: string? = nil
local force = false
local i = 1
while i <= #args do
	local a = args[i]
	if a == "--session" then
		sessionFlag = args[i + 1]
		i += 1
	elseif a == "--why" then
		why = args[i + 1]
		i += 1
	elseif a == "--force" then
		force = true
	elseif a == "check" or a == "report" or a == "base" or a == "allowed" then
		mode = a
	else
		error(`quest_budget: unknown argument {a}`, 0)
	end
	i += 1
end

local function pct(x: number): string
	return string.format("%.1f%%", x * 100)
end

local function printShares()
	for _, variant in { { false, "model (SIDE_SHARE)" }, { true, "player does everything" } } do
		print(`Quest EXP share per band, {variant[2]}:`)
		for _, band in Gen.shares(variant[1]) do
			local parts = {}
			for _, cat in Gen.CATEGORIES do
				local target = BudgetData.TARGET[cat] or 0
				table.insert(parts, `{cat} {pct(band.byCategory[cat] or 0)} (target {pct(target)})`)
			end
			print(`  {band.lo}-{band.hi}: {table.concat(parts, ", ")}, total {pct(band.total)}`)
		end
	end
end

if mode == "base" then
	if fs.isFile(Gen.BASE_PATH) and not force then
		print("base exists; only the final audit (S109) may rebase it")
		process.exit(1)
	end
	local git = process.exec("git", { "rev-parse", "HEAD" })
	local commit = if git.ok then string.gsub(git.stdout, "%s+$", "") else "unknown"
	local date = os.date("!%Y-%m-%d") :: string
	local file = Gen.baseFile(Gen.session(sessionFlag), commit, date)
	fs.writeFile(Gen.BASE_PATH, serde.encode("json", file, true) .. "\n")
	print(`wrote {Gen.BASE_PATH} ({file.meta.session}, {commit})`)
	process.exit(0)
end

if mode == "allowed" then
	if not why then
		error('quest_budget allowed: --why "<text>" is required', 0)
	end
	local r = Gen.allowed(why :: string)
	print(r.text)
	print(
		`-- {#r.entries} entries: {#r.added} new, {#r.changed} changed, {#r.dead} dead (remove: {table.concat(
			r.dead,
			", "
		)})`
	)
	process.exit(0)
end

local computed = Gen.compute()
local current = Gen.read()
local changed = Gen.diff(current, computed.mul)

if mode == "check" then
	if #changed == 0 then
		print("MONSTER_EXP_MUL is up to date")
		process.exit(0)
	end
	print(`MONSTER_EXP_MUL is out of date ({#changed} levels): run \`lune run tools/quest_budget.luau\``)
	for n = 1, math.min(10, #changed) do
		local L = changed[n]
		print(`  L{L}: {string.format("%.3f", current[L])} -> {string.format("%.3f", computed.mul[L])}`)
	end
	process.exit(1)
end

print("L   before -> after   s0      s")
for _, L in changed do
	local r = computed.rows[L]
	print(string.format("%-3d %.3f -> %.3f   %.4f  %.4f", L, current[L], computed.mul[L], r.s0, r.s))
end
print(
	`changed levels: {#changed}; clamped: {if #computed.clamped > 0
		then table.concat(computed.clamped, ", ")
		else "none"}`
)
printShares()
for _, g in Gen.grind(computed.mul) do
	print(
		string.format("grind %d-%d: base %.0f EXP-units, now %.0f (x%.4f)", g.lo, g.hi, g.base, g.now, g.now / g.base)
	)
end

if mode == "write" then
	local source = fs.readFile(Gen.DATA_PATH)
	local out = Gen.replaceBlock(source, Gen.render(computed.mul))
	if out ~= source then
		fs.writeFile(Gen.DATA_PATH, out)
		print(`wrote {Gen.DATA_PATH}`)
	else
		print(`{Gen.DATA_PATH} unchanged`)
	end
	print("Ledger line for tools/balance_reasons.luau:")
	print(
		`\t\t["QuestBudget:MONSTER_EXP_MUL*"] = \{ \{ session = "{Gen.session(sessionFlag)}", why = "regenerated: <what changed in the quests>" \} \},`
	)
end
