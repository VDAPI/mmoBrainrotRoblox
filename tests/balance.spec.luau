--!strict
-- Balance targets, checked with the model in tests/Balance.luau (expected values from the game's own modules).
--   * S32 targets of levels 1-20 (Balance.targets1_20): a report until S91 retunes 1-20 (owner answer 4); the
--     structural checks of the S32 blocks stay asserted. The 1-20 numbers themselves: tests/balance1_20.spec.
--   * Global targets 20-100 (Balance.targetsGlobal, G1-G6, G11-G13): a report until S87 sets GLOBAL_ASSERT.
--   * Regions (Balance.targetsRegion): asserted where Balance.TUNED says so (S83: the Meadows' kinds and Grimrok's
--     schedule only), printed elsewhere.
--   * The balance ledger (S83, balance plan 2.6): always asserted.
-- Model checks (boss schedule, quests, potions, cave Elites, boss constants): tests/balancemodel.spec.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local B = require("./Balance")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Loot = require("../src/shared/Logic/Loot")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local T = require("./Test")

local S32_ASSERT = false -- S83: report mode until S91 (owner answer 4)
local GLOBAL_ASSERT = false -- S87 turns this on
-- Region switches and thresholds live in tests/Balance.luau (TUNED, REGION_TARGETS: the report reads them too).
local TUNED = B.TUNED
local REGION_TARGETS = B.REGION_TARGETS

local function fmt(v: number?): string
	return if v == nil then "–" else string.format("%.3f", v)
end

local function describeRow(row: B.TargetRow): string
	return `{row.id} ({row.label}): {fmt(row.value)} poza [{fmt(row.low)}, {fmt(row.high)}]`
end

-- Prints "<title>: x/y w paśmie" and up to `limit` rows out of band.
local function printReport(title: string, rows: { B.TargetRow }, limit: number)
	local out = {}
	for _, row in rows do
		if not B.inBand(row) then
			table.insert(out, row)
		end
	end
	print(`{title}: {#rows - #out}/{#rows} w paśmie`)
	for i = 1, math.min(limit, #out) do
		print(`  {describeRow(out[i])}`)
	end
	if #out > limit then
		print(`  … i {#out - limit} więcej (docs/BALANS.md)`)
	end
end

T.describe("Balance S32: targets 1-20 (report until S91)", function()
	local rows = B.targets1_20()
	if S32_ASSERT then
		for _, row in rows do
			T.it(`{row.id}: {row.label}`, function()
				if not B.inBand(row) then
					error(describeRow(row), 0)
				end
			end)
		end
	else
		T.it("S32 targets (report until S91)", function()
			printReport("S32", rows, 40)
			T.expect(#rows > 400).toBe(true)
		end)
	end
end)

T.describe("Balance S32: structural checks", function()
	T.it("bigger groups hit softer per member", function()
		local last = math.huge
		for n = 1, 4 do
			local mul = MonsterStats.groupDamageMul(n)
			T.expect(mul <= last).toBe(true)
			last = mul
		end
		T.expect(MonsterStats.groupDamageMul(nil)).toBe(1)
		T.expect(MonsterStats.groupDamageMul(9)).toBe(MonsterStats.groupDamageMul(4))
	end)

	T.it("weapon bonuses never roll stats of another class", function()
		for _, id in ItemRoll.bonusPool("sword1h_20") do
			T.expect(id ~= "int" and id ~= "magAtk" and id ~= "dex" and id ~= "mana").toBe(true)
		end
		for _, id in ItemRoll.bonusPool("wand_20") do
			T.expect(id ~= "str" and id ~= "physAtk" and id ~= "dex").toBe(true)
		end
		-- Jewellery follows the class it dropped for.
		T.expect(table.find(ItemRoll.bonusPool("ring_20", "Warrior"), "int")).toBeNil()
		T.expect(table.find(ItemRoll.bonusPool("ring_20", "Mage"), "int") ~= nil).toBe(true)
		T.expect(table.find(ItemRoll.bonusPool("ring_20"), "int") ~= nil).toBe(true)
	end)

	T.it("drops are never above the monster's level; Elites drop at their spawner's level", function()
		for level = 1, 20 do
			local low, high = ItemRoll.dropLevelRange(level)
			T.expect(high).toBe(level)
			T.expect(low).toBe(math.max(1, level - 2))
		end
		T.expect(B.wearableShare(10)).toBe(1)
		T.expect(Loot.dropBaseLevel(22, "elite2", 20)).toBe(18)
		T.expect(Loot.dropBaseLevel(22, "elite", 20)).toBe(20)
		T.expect(Loot.dropBaseLevel(20, "elite", 18)).toBe(18)
		T.expect(Loot.dropBaseLevel(10, "normal", nil)).toBe(10)
	end)

	T.it("the generic kind pays exactly 1", function()
		T.expect(MonsterStats.kindReward(B.GENERIC :: any)).toBe(1)
		T.expect(B.kindReward(B.GENERIC)).toBe(1)
	end)

	T.it("gold from monsters far below the player drops (half the EXP penalty)", function()
		T.expect(MonsterStats.goldLevelMultiplier(20, 20)).toBe(1)
		T.expect(MonsterStats.goldLevelMultiplier(20, 15)).toBe(1)
		T.expect(MonsterStats.goldLevelMultiplier(10, 20)).toBe(1) -- never a bonus
		local mul = MonsterStats.goldLevelMultiplier(20, 10)
		T.expect(mul).toBeBetween(0.5, 0.75)
		T.expect(B.killGold(20, B.GENERIC, 20) > B.killGold(20, B.GENERIC, 10)).toBe(true)
	end)
end)

-- Balance ledger (S83, balance plan 2.6) ------------------------------------------------------------------------

local Reasons = (require :: any)("../tools/balance_reasons")
local SNAPSHOT = "tools/balance_before.json"

local function listDataFiles(dir: string, prefix: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			listDataFiles(path, `{prefix}{name}/`, out)
		else
			local base = string.match(name, "^(.+)%.luau$")
			if base then
				table.insert(out, `{prefix}{base}`)
			end
		end
	end
end

-- NOT_BALANCE pattern: `*` stands for exactly one whole path segment.
local function matchesPattern(path: string, pattern: string): boolean
	local a, b = string.split(path, "/"), string.split(pattern, "/")
	if #a ~= #b then
		return false
	end
	for i, seg in b do
		if seg ~= "*" and seg ~= a[i] then
			return false
		end
	end
	return true
end

T.describe("Balance ledger (S83)", function()
	local dump: { [string]: number } = {}

	T.it("every BALANCE_MODULES module loads", function()
		for _, entry in Reasons.BALANCE_MODULES do
			local ok, err = pcall(B.requireShared, entry.path)
			if not ok then
				error(`{entry.path}: {err}`, 0)
			end
		end
		dump = B.ledgerData(Reasons)
		T.expect(next(dump) ~= nil).toBe(true)
	end)

	T.it("every Data module is on exactly one list", function()
		local files = {}
		listDataFiles("src/shared/Data", "Data/", files)
		table.sort(files)
		local wrong = {}
		for _, path in files do
			local balance = 0
			for _, entry in Reasons.BALANCE_MODULES do
				if entry.path == path then
					balance += 1
				end
			end
			local other = 0
			for pattern in Reasons.NOT_BALANCE do
				if matchesPattern(path, pattern) then
					other = 1
				end
			end
			if balance + other ~= 1 then
				table.insert(wrong, `{path} ({balance} x BALANCE_MODULES, {other} x NOT_BALANCE)`)
			end
		end
		for _, entry in Reasons.BALANCE_MODULES do
			if not table.find(files, entry.path) then
				table.insert(wrong, `{entry.path}: no such Data file`)
			end
		end
		if #wrong > 0 then
			error(table.concat(wrong, "; "), 0)
		end
	end)

	T.it("the dump holds no secrets", function()
		for key in dump do
			local bad = string.sub(key, 1, 6) == "Codes:"
				or string.sub(key, 1, 9) == "Products:"
				or string.sub(key, 1, 14) == "AdminCommands:"
				or string.find(key, "AdminUserIds", 1, true) ~= nil
			if bad then
				error(`secret in the ledger dump: {key}`, 0)
			end
		end
	end)

	T.it("a newer * prefix explains a key with an older own entry", function()
		local before = { ["Monsters:[wolf].hpMul"] = 1, ["Monsters:[bear].hpMul"] = 1 }
		local now = { ["Monsters:[wolf].hpMul"] = 1.1, ["Monsters:[bear].hpMul"] = 1.1 }
		local reasons = {
			["Monsters:[wolf].hpMul"] = { { session = "S84", why = "old" } },
			["Monsters:*"] = { { session = "S88", why = "bulk" } },
		}
		local result = B.ledger(before, now, reasons, "S88")
		T.expect(#result.unexplained).toBe(0)
		for _, line in result.changed do
			T.expect(line.reason and line.reason.why).toBe("bulk")
		end
		reasons["Monsters:*"] = nil
		T.expect(#B.ledger(before, now, reasons, "S88").unexplained).toBe(2)
	end)

	T.it("every reason names a session and why", function()
		for key, list in Reasons.reasons do
			T.expect(#list > 0).toBe(true)
			for _, entry in list do
				if not (B.sessionNumber(entry.session) and type(entry.why) == "string" and entry.why ~= "") then
					error(`reasons[{key}]: session "S<n>" and a non-empty why`, 0)
				end
			end
		end
	end)

	T.it("every changed balance number since the snapshot has a reason", function()
		if not fs.isFile(SNAPSHOT) then
			print(`ledger: no {SNAPSHOT} (lune run tools/balance_report.luau snapshot)`)
			return
		end
		local snapshot = serde.decode("json", fs.readFile(SNAPSHOT))
		if type(snapshot.meta) ~= "table" or type(snapshot.data) ~= "table" then
			print(`ledger: {SNAPSHOT} has the old flat format (before S83): ledger skipped`)
			return
		end
		local result = B.ledger(snapshot.data, dump, Reasons.reasons, snapshot.meta.session)
		if #result.unexplained > 0 then
			local lines = {}
			for i = 1, math.min(10, #result.unexplained) do
				local key = result.unexplained[i]
				table.insert(lines, `{key}: {snapshot.data[key] or "–"} → {dump[key] or "–"}`)
			end
			error(
				`{#result.unexplained} balance number(s) changed without a reason in tools/balance_reasons.luau `
					.. `(snapshot {snapshot.meta.session}): {table.concat(lines, "; ")}`,
				0
			)
		end
	end)
end)

-- 20-100 ---------------------------------------------------------------------------------------------------------

T.describe("Balance 20-100: global (report until S87)", function()
	local rows = B.targetsGlobal()
	if GLOBAL_ASSERT then
		for _, row in rows do
			if row.report == nil then
				T.it(`{row.id} {row.label}`, function()
					if not B.inBand(row) then
						error(describeRow(row), 0)
					end
				end)
			end
		end
	end
	T.it("global targets G1-G6, G11-G13 (printed)", function()
		printReport("G", rows, 15)
		T.expect(#rows > 0).toBe(true)
	end)
end)

T.describe("Balance 20-100: regions", function()
	for _, mapId in B.REGION_IDS do
		local rows = B.targetsRegion(mapId, REGION_TARGETS)
		if TUNED[mapId] then
			-- S83: the Meadows assert the kinds and Grimrok's schedule; their Elites, pairs and Elite II belong to the
			-- 1-20 retune (S91) and are only printed.
			local asserted = if mapId == "meadows" then { kinds = true, bossCadence = true } else nil
			for _, row in rows do
				if asserted == nil or asserted[row.group] then
					T.it(`{row.id}`, function()
						if not B.inBand(row) then
							error(describeRow(row), 0)
						end
					end)
				end
			end
		end
		T.it(`{mapId}: region targets (printed{if TUNED[mapId] then "" else ", not tuned"})`, function()
			printReport(`region {mapId}`, rows, 8)
			T.expect(#rows > 0).toBe(true)
		end)
	end
end)
