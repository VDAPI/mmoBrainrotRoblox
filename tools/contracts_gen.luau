--!strict
-- Hunting contracts (S99, DESIGN-15 §3.3). Run from the repo root after every change of the hunting grounds
-- (Data/Areas lv / groups) or of Data/Quests/Contracts.RULES, then `lune run tools/quest_budget.luau`:
--   lune run tools/contracts_gen.luau          rewrites the GENERATED block of src/shared/Data/Quests/Contracts.luau
--   lune run tools/contracts_gen.luau check    exit 1 when the list in the file differs from Logic/ContractGen.build
-- Both print the area use counts, the longest run, the fallbacks and n / kills of a whole level (Warrior model).

local fs = require("@lune/fs")
local process = require("@lune/process")

local Balance = require("../tests/Balance")
local BudgetData = require("../src/shared/Data/QuestBudget")
local ContractGen = require("../src/shared/Logic/ContractGen")
local Contracts = require("../src/shared/Data/Quests/Contracts")
local Exp = require("../src/shared/Logic/Exp")

local DATA_PATH = "src/shared/Data/Quests/Contracts.luau"
local BEGIN = "-- BEGIN GENERATED (tools/contracts_gen.luau)"
local END = "-- END GENERATED"
local REPORT_LEVELS = { 1, 5, 10, 15, 20, 30, 45, 60, 80, 99 }

local mode = "write"
for _, a in process.args do
	if a == "check" then
		mode = "check"
	else
		error(`contracts_gen: unknown argument {a}`, 0)
	end
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function render(list: { any }): string
	local lines = { BEGIN, "local LIST: { Types.ContractQuest } = {" }
	for _, c in list do
		local obj = c.objectives[1]
		table.insert(lines, "\t{")
		table.insert(lines, `\t\tid = "{c.id}",`)
		table.insert(lines, `\t\tlevel = {c.level},`)
		table.insert(lines, `\t\tcategory = "contract",`)
		table.insert(lines, `\t\tmap = "{c.map}",`)
		table.insert(lines, `\t\tarea = "{c.area}",`)
		table.insert(lines, `\t\tobjectives = \{ \{ type = "kill", n = {obj.n}, area = "{obj.area}" \} \},`)
		local reward = `exp = {c.reward.exp}, gold = {c.reward.gold}`
		if c.reward.items then
			local items = {}
			for _, item in c.reward.items do
				table.insert(items, `\{ id = "{item.id}", n = {item.n} \}`)
			end
			reward ..= `, items = \{ {table.concat(items, ", ")} \}`
		end
		table.insert(lines, `\t\treward = \{ {reward} \},`)
		table.insert(lines, "\t},")
	end
	table.insert(lines, "}")
	table.insert(lines, END)
	return table.concat(lines, "\n")
end

local share = BudgetData.TARGET.contract
local built = ContractGen.build(Contracts.RULES, share)

for _, line in ContractGen.report(built) do
	print(line)
end
local ratios = {}
for _, L in REPORT_LEVELS do
	local contract = built[L]
	-- kills of a whole level without quests (paceAt.kills is what is left after the quest credit of the level)
	local kills = Exp.expToNext(L) / Balance.paceAt("Warrior", L).expPerKill
	local text = if kills > 0 then string.format("%.2f", contract.objectives[1].n / kills) else "n/a"
	table.insert(ratios, `L{L} {contract.objectives[1].n}/{string.format("%.0f", kills)} = {text}`)
end
print(`n / kills of a whole level (Warrior, expToNext / Balance.paceAt.expPerKill): {table.concat(ratios, "; ")}`)

if mode == "check" then
	if deepEqual(Contracts.list, built) then
		print("Data/Quests/Contracts is up to date")
		process.exit(0)
	end
	print("Data/Quests/Contracts is out of date: run `lune run tools/contracts_gen.luau`, then tools/quest_budget.luau")
	process.exit(1)
end

local source = fs.readFile(DATA_PATH)
local a = string.find(source, BEGIN, 1, true)
local b0, b1 = string.find(source, END, a or 1, true)
if not a or not b0 or not b1 then
	error(`{DATA_PATH}: the GENERATED markers are missing`, 0)
end
local out = string.sub(source, 1, a - 1) .. render(built) .. string.sub(source, b1 + 1)
if out == source then
	print(`{DATA_PATH} unchanged`)
else
	fs.writeFile(DATA_PATH, out)
	print(`wrote {DATA_PATH} ({#built} contracts)`)
end
local ok, result = pcall(process.exec, "stylua", { DATA_PATH })
if ok and result.ok then
	print(`stylua {DATA_PATH}: ok`)
else
	print(`run \`stylua {DATA_PATH}\` (stylua not found in PATH or failed)`)
end
print("next: lune run tools/quest_budget.luau")
