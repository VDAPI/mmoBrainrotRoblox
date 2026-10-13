--!strict
-- Balance targets, checked with the model in tests/Balance.luau (expected values from the game's own modules).
--   * S32 targets of levels 1-20 (Balance.targets1_20): a report until S91 retunes 1-20 (owner answer 4); the
--     structural checks of the S32 blocks stay asserted. The 1-20 numbers themselves: tests/balance1_20.spec.
--   * Global targets 20-100 (Balance.targetsGlobal, G1-G9, G11-G13; G7-G9 from S84): asserted from S87
--     (GLOBAL_ASSERT) except Balance.GLOBAL_REPORT_ONLY.
--   * Regions (Balance.targetsRegion): asserted where Balance.TUNED says so (S83: the Meadows' kinds and Grimrok's
--     schedule only), printed elsewhere.
--   * The balance ledger (S83, balance plan 2.6): always asserted.
--   * S85: G10 (T-SK4, T-SK5 of tests/SkillModel) in the global block, the Meadows' T-SK3 / T-SK6 printed in the
--     region block, the block "Skill model (S85)" at the end.
--   * S86: the Meadows' T-SK rows without `report` asserted, the blocks "SkillModel: class mechanics (S86)" and
--     "Balance 20-100: paths" (PATHS_TUNED, tests/fixtures/balance_paths.json) at the end.
--   * Items, loot and monster defence 20-100 (S84): the tables of BalanceTables.tablesItems against
--     tests/fixtures/balance_items.json, S32 compatibility and Monte Carlo on the game's functions; D5 rows in the
--     region block (REGION_TARGETS.d5, under TUNED).
-- Model checks (boss schedule, quests, potions, cave Elites, boss constants): tests/balancemodel.spec.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local B = require("./Balance")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Loot = require("../src/shared/Logic/Loot")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local T = require("./Test")

local S32_ASSERT = false -- S83: report mode until S91 (owner answer 4)
-- S87 (J1): rows of the global block left to a later session (the table lives in tests/Balance.luau, the report reads
-- it too); every other row without `report` is asserted.
local GLOBAL_REPORT_ONLY = B.GLOBAL_REPORT_ONLY
local GLOBAL_ASSERT = true -- S87
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

T.describe("Balance 20-100: global (asserted from S87)", function()
	local rows = B.targetsGlobal()
	-- S85 (J2): G10 = T-SK4 (Mage) and T-SK5 (Cleric) from tests/SkillModel, in the same mode
	for _, row in (require :: any)("./SkillModel").targetsG10() do
		table.insert(rows, row)
	end
	local asserted, reported = {}, {}
	for _, row in rows do
		if row.report ~= nil then
			continue
		elseif B.reportOnlyFor(row) then
			table.insert(reported, row)
		else
			table.insert(asserted, row)
		end
	end
	if GLOBAL_ASSERT then
		T.it("every row outside GLOBAL_REPORT_ONLY is in band", function()
			local bad = {}
			for _, row in asserted do
				if not B.inBand(row) then
					table.insert(bad, describeRow(row))
				end
			end
			if #bad > 0 then
				error(`{#bad} row(s) out of band: {table.concat(bad, "; ", 1, math.min(#bad, 20))}`, 0)
			end
		end)
	end
	T.it("GLOBAL_REPORT_ONLY: every key matches a row, every session is above S87", function()
		for key, entry in GLOBAL_REPORT_ONLY do
			local found = false
			for _, row in rows do
				if B.reportKeyMatches(key, row) then
					found = true
					break
				end
			end
			if not found then
				error(`GLOBAL_REPORT_ONLY: dead key {key}`, 0)
			end
			T.expect({ key = key, later = (B.sessionNumber(entry.session) or 0) > 87 })
				.toEqual({ key = key, later = true })
			T.expect({ key = key, why = #entry.why > 0 }).toEqual({ key = key, why = true })
		end
	end)
	T.it("global targets G1-G13 (printed)", function()
		local inBand = 0
		for _, row in asserted do
			inBand += if B.inBand(row) then 1 else 0
		end
		print(`G: {inBand}/{#asserted} w paśmie, w raporcie: {#reported}`)
		local out = 0
		for _, row in reported do
			if not B.inBand(row) then
				out += 1
				if out <= 15 then
					local entry = B.reportOnlyFor(row) :: any
					print(`  {row.id} ({row.label}): {fmt(row.value)} → {entry.session}`)
				end
			end
		end
		if out > 15 then
			print(`  … i {out - 15} więcej (docs/BALANS.md)`)
		end
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
		if mapId == "meadows" then
			-- S85 (J2) / S86 (F4): T-SK3 and T-SK6 at L20; the rows without `report` are asserted (the Meadows are
			-- tuned), the rest printed until S91 (SkillModel.MEADOWS_REPORT names each with its value)
			local skillRows = (require :: any)("./SkillModel").targetsMeadows()
			for _, row in skillRows do
				if row.report == nil then
					T.it(`{row.id}`, function()
						if not B.inBand(row) then
							error(describeRow(row), 0)
						end
					end)
				end
			end
			T.it("meadows: T-SK3 and T-SK6 at L20 (asserted without report, the rest printed)", function()
				printReport("region meadows T-SK (S85-S86)", skillRows, 8)
				T.expect(#skillRows > 0).toBe(true)
			end)
		end
	end
end)

-- Items, loot and monster defence 20-100 (S84) --------------------------------------------------------------------
-- One case per table group: the keys of tests/fixtures/balance_items.json, finite values, the dependencies that follow
-- from the definitions, and the fixture: with the same data (dataHash) every value within its tolerance; with
-- changed data (S87 and later) the differences are only printed. Plus the S32 compatibility checks and Monte Carlo
-- on the game's functions (Logic/Rng, fixed seeds).

local AreaProfiles = require("../src/shared/Data/AreaProfiles")
local AreaRates = require("../src/shared/Logic/AreaRates")
local BalanceTables = require("./BalanceTables")
local Bonuses = require("../src/shared/Data/Bonuses")
local FightSim = require("../src/shared/Logic/FightSim")
local Items = require("../src/shared/Data/Items")
local LootTables = require("../src/shared/Data/LootTables")
local LuckData = require("../src/shared/Data/Luck")
local Monsters = require("../src/shared/Data/Monsters")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Upgrade = require("../src/shared/Logic/Upgrade")

-- Table title patterns of each case.
local ITEM_GROUPS: { { name: string, patterns: { string } } } = {
	{ name = "G7", patterns = { "^G7: " } },
	{ name = "G8", patterns = { "^G8: ", "^Bronie Łowcy" } },
	{ name = "cechy", patterns = { "^Cechy broni", "^Przeszycie" } },
	{ name = "G9", patterns = { "^G9: ", "^Koszt %+1" } },
	{ name = "materiały", patterns = { "^Popyt", "^Podaż", "^Godziny" } },
	{ name = "luki ilvl", patterns = { "^Luki", "^Trwałość" } },
	{ name = "drop i szczęście", patterns = { "^Profile", "^Pola szczęścia", "^D5", "^Boss z Fortuną" } },
	{ name = "obrona", patterns = { "^Udział pancerza", "^Walka 1 na 1", "^Przeciw obronie" } },
}

local function inGroup(key: string, patterns: { string }): boolean
	for _, pattern in patterns do
		if string.find(key, pattern) then
			return true
		end
	end
	return false
end

-- Within 3 standard deviations of the mean or 5 % (K4).
local function near(mean: number, expected: number, sd: number, n: number): boolean
	local tol = math.max(3 * sd / math.sqrt(n), 0.05 * math.abs(expected))
	return math.abs(mean - expected) <= tol
end

local function stats(samples: { number }): (number, number)
	local sum = 0
	for _, v in samples do
		sum += v
	end
	local mean = sum / #samples
	local var = 0
	for _, v in samples do
		var += (v - mean) ^ 2
	end
	return mean, math.sqrt(var / math.max(1, #samples - 1))
end

T.describe("Balance 20-100: items, loot, defence (S84)", function()
	local values = BalanceTables.values(BalanceTables.tablesItems())
	local fixture = BalanceTables.readItemsFixture()
	local report = BalanceTables.itemsFixtureDiff(values)

	if fixture and not report.sameData then
		-- S87 and later change the data: no failure here (those sessions assert their own targets)
		print(
			`items fixture: data changed ({table.concat(report.changedModules, ", ")}); {#report.diffs} values moved, `
				.. "regenerate with `lune run tools/balance_report.luau --fixture-items` and note it in docs/SESJE.md"
		)
		for i = 1, math.min(10, #report.diffs) do
			local d = report.diffs[i]
			print(`  {d.key}: {d.before} → {d.after}`)
		end
		-- NaN cells are not keys, so a data change may add or drop keys too
		for i = 1, math.min(10, #report.missing) do
			print(`  missing {report.missing[i]}`)
		end
		for i = 1, math.min(10, #report.added) do
			print(`  new {report.added[i]}`)
		end
	end

	for _, group in ITEM_GROUPS do
		T.it(`{group.name}: fixture keys, finite values, the fixture with the same data`, function()
			local count = 0
			for key, v in values do
				if inGroup(key, group.patterns) then
					count += 1
					if v ~= v or v == math.huge or v == -math.huge then
						error(`{key}: not finite ({v})`, 0)
					end
				end
			end
			T.expect(count > 0).toBe(true)
			T.expect(fixture ~= nil).toBe(true)
			local problems = {}
			if report.sameData then
				for _, key in report.missing do
					if inGroup(key, group.patterns) then
						table.insert(problems, `missing {key}`)
					end
				end
				for _, key in report.added do
					if inGroup(key, group.patterns) then
						table.insert(problems, `new {key}`)
					end
				end
				for _, d in report.diffs do
					if inGroup(d.key, group.patterns) then
						table.insert(problems, `{d.key}: {d.before} → {d.after}`)
					end
				end
			end
			if #problems > 0 then
				error(
					"model się zmienił przy tych samych danych: sprawdź zmianę albo wygeneruj `--fixture-items` i "
						.. `opisz w SESJE ({#problems}): {table.concat(problems, "; ", 1, math.min(8, #problems))}`,
					0
				)
			end
		end)
	end

	T.it("G7: base only of Mythic >= Legendary; the S32 column is rarityGain", function()
		for _, c in B.CLASSES do
			for _, L in { 20, 45, 70, 100 } do
				local legendary = B.rarityGainAt(c, L, Rarities.LEGENDARY)
				local mythic = B.rarityGainAt(c, L, Rarities.MYTHIC)
				T.expect(mythic.baseOnly >= legendary.baseOnly).toBe(true)
				T.expect(legendary.s32).toBe(B.rarityGain(c, L, Rarities.LEGENDARY))
			end
		end
	end)

	T.it("G8: Common +0 without traits stays near the S32 parity", function()
		for _, pair in B.G8_PAIRS do
			local p = B.twoHandedParity(pair.classId, 45, pair.weapon, Rarities.COMMON, 0, { traits = false })
			T.expect(p.mix > 0.8 and p.mix < 1.2).toBe(true)
			T.expect(p.worst <= p.single).toBe(true)
		end
	end)

	T.it("cechy: traitValue of a trait switched off by traitScale is 0", function()
		for _, id in { "swordplay", "beheading", "toxicBarbs", "elementalSpark", "parry", "savingBlow" } do
			local spec = B.TRAIT_SETS[id]
			local classId, gear = B.traitGear(id, Rarities.COMMON, 0)
			local off = B.withoutTrait(gear, id)
			for _, situation in spec[4] :: { string } do
				T.expect(B.traitValue(classId, 45, off, id, situation)).toBe(0)
			end
		end
	end)

	T.it("cechy: Reaping heals once per kill in solo; Run Through at behindShare = traitValue", function()
		for _, L in { 20, 100 } do
			local classId, gear = B.traitGear("reaping", Rarities.COMMON, 0)
			local p = B.itemPlayer(classId, L, gear)
			local ctx = B.situationCtx(p, "solo")
			local t = B.traitTerms(p, ctx.m, ctx)
			T.expect(t.killHealHp).toBeNear(p.hooks.killHeal * p.values.maxHp / 100, 1e-9)
			-- the loss per kill does not depend on the kill rate (the cached ctx is restored after)
			local loss = B.situationMeasure(p, "solo")
			local kills = ctx.kills
			ctx.kills = kills * 10
			local faster = B.situationMeasure(p, "solo")
			ctx.kills = kills
			T.expect(faster).toBeNear(loss, 1e-9)
			for _, situation in { "group", "boss" } do
				local share = B.SITUATIONS.behindShare
				local run = B.runThroughValue(L, Rarities.COMMON, 0, share, situation)
				local _, runGear = B.traitGear("runThrough", Rarities.COMMON, 0)
				T.expect(run).toBeNear(B.traitValue("Warrior", L, runGear, "runThrough", situation), 1e-9)
				T.expect(B.runThroughValue(L, Rarities.COMMON, 0, 0.5, situation) > run).toBe(true)
			end
		end
	end)

	T.it("G9: without protection costs more; protected gold = upgradeGold", function()
		for _, ilvl in { 18, 43, 68, 98 } do
			local item = B.makeItem("sword1h_1", ilvl, Rarities.LEGENDARY, 0, {})
			local protected, free = B.upgradePlan(item, 9, true), B.upgradePlan(item, 9, false)
			T.expect(free.gold >= protected.gold).toBe(true)
			T.expect(free.cores >= protected.cores).toBe(true)
			local common = B.makeItem("sword1h_1", ilvl, Rarities.COMMON, 0, {})
			T.expect(B.upgradePlan(common, 9, true).gold).toBe(B.upgradeGold(ilvl, 9))
			T.expect(B.upgradePlan(common, 3, true).gold).toBe(B.upgradeGold(ilvl, 3))
		end
	end)

	T.it("materiały: demand and supply are non-negative; unprotected needs more crystals", function()
		local byLabel = {}
		for _, need in B.materialDemand() do
			byLabel[need.label] = need
			T.expect(need.dust >= 0 and need.shards >= 0 and need.crystals >= 0).toBe(true)
		end
		local a, b =
			byLabel["legendary · broń · +9 · bez ochrony"], byLabel["legendary · broń · +9 · z ochroną"]
		T.expect(a.crystals > b.crystals and a.cores > b.cores).toBe(true)
		local s = B.materialSupply("Warrior", 70)
		for _, list in { s.normal, s.elite, s.elite2, s.bossWeek } do
			for _, v in list do
				T.expect(v >= 0).toBe(true)
			end
		end
	end)

	T.it("luki ilvl: a normal drop is never above the player; no source drops above the player", function()
		for r = 2, #B.BANDS do
			for _, g in B.ilvlGaps(r) do
				T.expect(g.normal >= 0).toBe(true)
				T.expect(g.elite ~= g.elite or g.elite >= 0).toBe(true)
				T.expect(g.elite2 ~= g.elite2 or g.elite2 >= 0).toBe(true)
				T.expect(g.boss >= 0).toBe(true)
			end
		end
	end)

	T.it("drop i szczęście: itemBonus = min(personal + fortune, monsterItemCap); the model never caps", function()
		for _, profile in B.LUCK_PROFILES do
			for _, L in { 25, 45, 70, 100 } do
				for _, fortune in { false, "start", "full" } do
					local luck = B.monsterLuck(profile.id, L, if fortune then fortune :: any else nil)
					T.expect(luck.itemBonus).toBe(math.min(luck.personal + luck.fortune, LuckData.monsterItemCap))
					T.expect(luck.personal).toBe(B.luckProfile(profile.id, L).dropBonus)
				end
			end
		end
	end)

	T.it("obrona: armoured and warded kinds keep more than the generic one", function()
		for _, L in B.ITEM_LEVELS do
			local generic = B.monster(B.GENERIC, L)
			for _, entry in B.defenceKinds() do
				local m = B.monster(entry.kind, L)
				if (entry.kind.defMul or 1) > 1 then
					T.expect(B.armorShare(m, L, false) > B.armorShare(generic, L, false)).toBe(true)
				end
				if (entry.kind.mresMul or 1) > 1 then
					T.expect(B.armorShare(m, L, true) > B.armorShare(generic, L, true)).toBe(true)
				end
			end
		end
	end)

	-- Compatibility with S32 (K3)

	T.it("power without options is the S32 sqrt(DPS x EHP)", function()
		for _, c in B.CLASSES do
			local p = B.player(c, 45)
			local m = B.monster(B.GENERIC, 45)
			local hit = FightSim.hit(m, p :: any)
			local expected = math.sqrt(FightSim.dps(p :: any, m, B.SKILL_DPS) * (p.values.maxHp / math.max(hit, 1e-6)))
			T.expect(B.power(p)).toBe(expected)
		end
	end)

	T.it("traitScale of only 1 gives the same player bit for bit", function()
		local ones = {}
		for id in B.NO_TRAITS do
			ones[id] = 1
		end
		for _, c in B.CLASSES do
			for _, weapon in { false, true } do
				local opts = if weapon then { rarity = Rarities.MYTHIC, up = 9 } else nil
				local a = B.player(c, 70, opts)
				local b = B.player(c, 70, B.withOpts(opts, { traitScale = ones }))
				T.expect(b.values).toEqual(a.values)
				T.expect(b.hooks).toEqual(a.hooks)
			end
		end
	end)

	-- Monte Carlo on the game's functions (K4)

	T.it("Monte Carlo: Loot.rollMonsterLoot against items, rarity, class share and materials per kill", function()
		local Loot = require("../src/shared/Logic/Loot")
		local kind = "ashOrc"
		local def = Monsters.get(kind) :: any
		local tableDef = LootTables.byId[def.lootTable]
		local level = 55
		for i, variant in { "normal", "elite", "elite2" } do
			local rng = Rng.new(8400 + i)
			local mods = table.clone(AreaProfiles.NEUTRAL) :: any
			mods.topTierMul = 1.5
			local n = if variant == "normal" then 20000 else 6000
			local counts, tops, usable, dust = {}, 0, 0, {}
			local items = 0
			local expectedCount, topShare = AreaRates.itemsPerKill(variant, mods, 20)
			local weights = Rarities.dropWeights[variant]
			local cap = Rarities.cap[variant]
			local top = 0
			for rarity, w in weights do
				if w > 0 and rarity <= cap and rarity > top then
					top = rarity
				end
			end
			for k = 1, n do
				local result = Loot.rollMonsterLoot(
					kind,
					variant,
					level,
					rng,
					{ dropBonus = 20, classId = "Mage", topTierMul = 1.5, dropLevel = level }
				)
				counts[k] = #result.items
				items += #result.items
				for _, item in result.items do
					tops += if item.rarity == top then 1 else 0
					local itemDef = Items.get(item.defId) :: any
					usable += if itemDef.classes == nil or table.find(itemDef.classes, "Mage") then 1 else 0
				end
				local d = 0
				for _, mat in result.materials do
					if mat.id == "essence_dust" then
						d += mat.n
					end
				end
				dust[k] = d
			end
			local mean, sd = stats(counts)
			if not near(mean, expectedCount, sd, n) then
				error(`{variant}: {mean} items per kill, model {expectedCount}`, 0)
			end
			local share = tops / items
			if not near(share, topShare, math.sqrt(topShare * (1 - topShare)), items) then
				error(`{variant}: top rarity share {share}, model {topShare}`, 0)
			end
			local expectedUsable = B.usableAt(tableDef.slotWeights, level, tableDef.classBias, "Mage")
			local p = usable / items
			if not near(p, expectedUsable, math.sqrt(expectedUsable * (1 - expectedUsable)), items) then
				error(`{variant}: class share {p}, model {expectedUsable}`, 0)
			end
			local dustMean, dustSd = stats(dust)
			local expectedDust = B.materialsPerKill(kind, variant).essence_dust or 0
			if not near(dustMean, expectedDust, dustSd, n) then
				error(`{variant}: dust per kill {dustMean}, model {expectedDust}`, 0)
			end
		end
	end)

	T.it("Monte Carlo: Upgrade.attempt chains against upgradePlan attempts (3 %)", function()
		local item = B.makeItem("sword1h_1", 60, Rarities.HEROIC, 0, {})
		for _, protect in { true, false } do
			local rng = Rng.new(if protect then 841 else 842)
			local n = if protect then 4000 else 4000
			local samples: { number } = {}
			for k = 1, n do
				local up, attempts = 0, 0
				while up < 9 do
					local result = Upgrade.attempt({ up = up } :: any, protect, rng)
					up = result.to
					attempts += 1
				end
				samples[k] = attempts
			end
			local expected = B.upgradePlan(item, 9, protect).attempts
			local mean, sd = stats(samples)
			if math.abs(mean - expected) > math.max(0.03 * expected, 3 * sd / math.sqrt(n)) then
				error(`{if protect then "protected" else "unprotected"}: {mean} attempts, model {expected}`, 0)
			end
		end
	end)

	T.it("Monte Carlo: Loot.pickItem against usableShare", function()
		local Loot = require("../src/shared/Logic/Loot")
		local slots = LootTables.byId.wolf.slotWeights
		for i, spec in { { "Hunter", 50, 0.8 }, { "Cleric", 85, 0.8 }, { "Warrior", 25, 0.5 } } do
			local classId, ilvl, bias = spec[1] :: string, spec[2] :: number, spec[3] :: number
			local rng = Rng.new(8450 + i)
			local n, usable = 20000, 0
			for _ = 1, n do
				local id = Loot.pickItem(slots, ilvl, bias, classId, rng)
				local def = if id then Items.get(id) :: any else nil
				if def and (def.classes == nil or table.find(def.classes, classId)) then
					usable += 1
				end
			end
			local expected = B.usableShare(slots, ilvl, bias, classId)
			local p = usable / n
			if not near(p, expected, math.sqrt(expected * (1 - expected)), n) then
				error(`{classId} {ilvl}: {p} usable, model {expected}`, 0)
			end
		end
	end)

	T.it("Monte Carlo (P2): ItemRoll.rollItem lines against expectedBonuses", function()
		local ItemRoll = require("../src/shared/Logic/ItemRoll")
		for i, spec in { { "ring", "Warrior" }, { "wand", "Mage" } } do
			local base, classId = spec[1] :: string, spec[2] :: string
			local defId = B.tierId(base, 45)
			local rng = Rng.new(8470 + i)
			local n = 8000
			local samples: { [string]: { number } } = {}
			local expected: { [string]: number } = {}
			for _, line in B.expectedBonuses(defId, 45, Rarities.HEROIC, classId) do
				if not string.find(line.stat, "^vs_") and not string.find(line.stat, "^res_") then
					expected[line.stat] = (expected[line.stat] or 0) + line.v
					samples[line.stat] = {}
				end
			end
			for k = 1, n do
				local item = ItemRoll.rollItem(defId, 45, Rarities.HEROIC, rng, "mc", classId)
				for stat in samples do
					samples[stat][k] = 0
				end
				for _, bonus in item.bonuses do
					if samples[bonus.stat] then
						samples[bonus.stat][k] += bonus.v
					end
				end
			end
			for stat, list in samples do
				local mean, sd = stats(list)
				-- S87: expectedBonuses takes the rounded middle of the range; with the pct scale capped at ilvl 20 the
				-- ranges are short, so a 0-decimal line may differ by up to half a rounding step x its share
				local def = Bonuses.get(stat)
				local share = expected[stat] / math.max(1e-9, ItemRoll.rollBonusValue(stat, 45, Rarities.HEROIC, 0.5))
				local rounding = if def then 0.5 * 10 ^ -def.decimals * share else 0
				if not near(mean, expected[stat], sd, n) and math.abs(mean - expected[stat]) > rounding then
					error(`{defId} {stat}: mean {mean}, expectedBonuses {expected[stat]}`, 0)
				end
			end
		end
	end)
end)

-- Skill model (S85) ---------------------------------------------------------------------------------------------
-- tests/SkillModel.luau: the control against FightSim.dps, the server rules it mirrors (ticks, restack, meteor storm),
-- the builds through Paths.canBuy, the rotation read from the data, costs / normalisation / DEX rating from the game's
-- functions and the shape of the T-SK numbers. The T-SK grid itself is a report (docs/BALANS.md), no fixture (S86
-- changes it on purpose).

local LevelCurves = require("../src/shared/Logic/LevelCurves")
local Paths = require("../src/shared/Logic/Paths")
local SkillData = require("../src/shared/Data/Skills")
local SkillModel = require("./SkillModel")
local Skills = require("../src/shared/Logic/Skills")
local StatCalc = require("../src/shared/Logic/StatCalc")
local Stats = require("../src/shared/Data/Stats")
local Traits = require("../src/shared/Logic/Traits")

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

-- A copy of a build with another key, rotation or weapon (the model caches by key).
local function variant(build: SkillModel.Build, key: string, changes: { [string]: any }): SkillModel.Build
	local copy: any = table.clone(build)
	copy.key = key
	for k, v in changes do
		copy[k] = v
	end
	return copy
end

T.describe("Skill model (S85)", function()
	T.it("control: without skills the model gives FightSim.dps within 1 % (4 classes x 20 / 45 / 70 / 100)", function()
		local agile: any = nil
		for _, entry in B.defenceKinds() do
			if entry.defence == "agile" then
				agile = entry.kind
				break
			end
		end
		assert(agile, "no agile family kind")
		for _, classId in B.CLASSES do
			for _, L in SkillModel.LEVELS do
				local base = SkillModel.builds(classId)[1]
				local players = {
					{ "base", SkillModel.player(base, L, if classId == "Mage" then { element = "fire" } else nil) },
					{ "convention", SkillModel.wrap(B.player(classId, L)) },
				}
				for _, entry in players do
					local sp = entry[2]
					for _, kind in { B.GENERIC, agile } do
						local m = B.monster(kind, L)
						local model = SkillModel.fight(sp, { skills = false, control = true, targets = { m } }).dps
						local expected = FightSim.dps(sp.p, m)
						if math.abs(model / expected - 1) > 0.01 then
							error(`{classId} {L} {entry[1]} {kind.family}: model {model}, FightSim.dps {expected}`, 0)
						end
					end
				end
			end
		end
	end)

	T.it("ticks: a 4 s bleed gives Traits.ticks(4) ticks; a refresh restacks without the old ticks", function()
		local ticks = SkillModel.timeline({ { t = 0, duration = 4, tick = 10 } }, 10)
		T.expect(#ticks).toBe(Traits.ticks(4))
		for _, tick in ticks do
			T.expect(tick[2]).toBe(10)
		end
		-- a 1 s effect: the server removes it before its first tick (Traits.ticks says 1, the timeline 0)
		T.expect(#SkillModel.timeline({ { t = 0, duration = 1, tick = 10 } }, 5)).toBe(0)
		-- bleedStacks 3, a second bleed after 2 s: 2 stacks, ends at 6, one tick a second (no old schedule left)
		local refreshed, left = SkillModel.timeline({
			{ t = 0, duration = 4, tick = 10, maxStacks = 3 },
			{ t = 2, duration = 4, tick = 10, maxStacks = 3 },
		}, 10)
		local times, total = {}, 0
		for _, tick in refreshed do
			table.insert(times, tick[1])
			total += tick[2]
		end
		T.expect(#refreshed).toBe(5) -- 1, 2 (one stack), 3, 4, 5 (two stacks); expired at 6
		T.expect(math.abs(total - (2 * 10 + 3 * 20)) < 1e-6).toBe(true)
		for i = 2, #times do
			T.expect(math.abs(times[i] - times[i - 1] - 1) < 1e-6).toBe(true)
		end
		T.expect(next(left)).toBe(nil)
	end)

	T.it("meteor storm: share of impacts from Offense.circleTarget's geometry", function()
		local storm = SkillData.get("meteorStorm") :: any
		local r = storm.radius or 8
		local ri = math.max(4, r / 3)
		local expected = math.min(1, (ri + 1.5) / (r - ri))
		T.expect(math.abs(SkillModel.stormShare(storm) - expected) < 1e-9).toBe(true)
		T.expect(expected < 1).toBe(true)
		T.expect(SkillModel.stormShare(SkillData.get("fireball") :: any)).toBe(1)
	end)

	T.it(
		"builds: reference ranks through Paths.canBuy, at most pointsAt(100); main path from 20; base rows only",
		function()
			for _, classId in B.CLASSES do
				for _, build in SkillModel.builds(classId) do
					local at100 = SkillModel.character(build, 100)
					if at100.spent > Paths.pointsAt(100) or at100.rankChecks ~= at100.spent then
						error(`{classId} {build.key}: spent {at100.spent}, canBuy {at100.rankChecks}`, 0)
					end
					T.expect(SkillModel.character(build, 19).character.path.main).toBe(nil)
					local at20 = SkillModel.character(build, 20)
					if at20.spent ~= Paths.pointsAt(20) and #at20.unbought == 0 then
						error(`{classId} {build.key}: {at20.spent} of {Paths.pointsAt(20)} at 20 without a reason`, 0)
					end
					if build.base then
						T.expect(at20.character.path.main).toBe(nil)
						local rows = SkillModel.BASE[classId].rows
						for nodeId in at100.character.path.nodes do
							local _, _, row = Paths.findNode(nodeId)
							if (row or 99) > rows then
								error(`{classId} base buys {nodeId} in row {row}`, 0)
							end
						end
					else
						T.expect(at20.character.path.main).toBe(build.pathId)
						T.expect(at100.spent).toBe(Paths.pointsAt(100))
					end
				end
			end
		end
	)

	T.it("rotation from the data: order, minFury from the Fury state, minEnemies on 3 dummies", function()
		local base = SkillModel.builds("Warrior")[1]
		local a = variant(base, "test.order.a", { rotation = { { skill = "mightyStrike" }, { skill = "bladeWhirl" } } })
		local b = variant(base, "test.order.b", { rotation = { { skill = "bladeWhirl" }, { skill = "mightyStrike" } } })
		local one = { B.monster(B.GENERIC, 45) }
		local ra = SkillModel.fight(SkillModel.player(a, 45), { targets = one, unlimited = true })
		local rb = SkillModel.fight(SkillModel.player(b, 45), { targets = one, unlimited = true })
		T.expect(ra.firstCasts[1]).toBe("mightyStrike")
		T.expect(rb.firstCasts[1]).toBe("bladeWhirl")
		local fury = variant(base, "test.fury", { rotation = { { skill = "mightyStrike", minFury = 5 } } })
		local rf = SkillModel.fight(SkillModel.player(fury, 45), { targets = one, unlimited = true })
		-- S86: minFury reads the Fury state (B5); the base has no Fury (no furyMax), so the entry never fires
		T.expect(rf.casts.mightyStrike).toBe(nil)
		T.expect(rf.skipped.mightyStrike).toBe(nil)
		local area = variant(base, "test.area", { rotation = { { skill = "bladeWhirl", minEnemies = 2 } } })
		local sp = SkillModel.player(area, 45)
		T.expect(SkillModel.fight(sp, { targets = one, unlimited = true }).casts.bladeWhirl).toBe(nil)
		local three = { B.monster(B.GENERIC, 45), B.monster(B.GENERIC, 45), B.monster(B.GENERIC, 45) }
		T.expect((SkillModel.fight(sp, { targets = three, unlimited = true }).casts.bladeWhirl or 0) > 0).toBe(true)
	end)

	T.it("resources and formulas: Skills.cost, flat energy / Cleric mana, weapon normalisation, DEX rating", function()
		-- Mage mana per cast = Skills.cost (the manaCost curve), Cleric and energy flat
		for _, spec in { { "Mage", "firebolt", 70 }, { "Cleric", "holyStrike", 70 }, { "Warrior", "mightyStrike", 70 } } do
			local classId, skillId, L = spec[1], spec[2], spec[3]
			local base = SkillModel.builds(classId)[1]
			local only = variant(base, `test.cost.{skillId}`, { rotation = { { skill = skillId } } })
			local sp = SkillModel.player(only, L, if classId == "Mage" then { element = "fire" } else nil)
			local r = SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, L) }, unlimited = true })
			local rank = Paths.skillRank(sp.character, skillId)
			local def = Paths.effectiveFor(sp.character, skillId, sp.weapons, rank)
			local cost = Skills.cost(def, rank, L, classId, {
				costReduce = sp.p.values.costReduce or 0,
				hooks = sp.pathHooks,
				charges = 0,
			})
			local casts = r.casts[skillId] or 0
			T.expect(casts > 0).toBe(true)
			T.expect(math.abs(r.spent / casts - cost) < 1e-6).toBe(true)
			local flat = Skills.scaled(def, def.cost, rank)
			if classId == "Mage" then
				T.expect(math.abs(cost / flat - LevelCurves.at("manaCost.Mage", L)) < 1e-6).toBe(true)
			else
				T.expect(math.abs(cost - flat) < 1e-6).toBe(true)
			end
		end
		-- the skill attack of the same Hunter with a heavy crossbow and a long bow (S54 case) within 1 %
		local hunter = SkillModel.builds("Hunter")[1]
		local heavy = variant(hunter, "test.heavycrossbow", { weapon = { main = "heavycrossbow", offhand = "quiver" } })
		local long = variant(hunter, "test.longbow", { weapon = { main = "longbow", offhand = "quiver" } })
		for _, L in SkillModel.LEVELS do
			local a, b = SkillModel.player(heavy, L), SkillModel.player(long, L)
			local attackA = a.p.values.physAtk * a.speedMul
			local attackB = b.p.values.physAtk * b.speedMul
			if math.abs(attackA / attackB - 1) > 0.01 then
				error(`Hunter {L}: heavy crossbow {attackA}, long bow {attackB}`, 0)
			end
		end
		-- the Hunter's crit at 100 is StatCalc's with the DEX rating (the model adds nothing)
		local sp = SkillModel.player(hunter, 100)
		local bare = StatCalc.compute({ level = 100, stats = sp.stats })
		local F = Stats.Formula
		local rated = F.critBase + F.critPerDex * bare.primary.dex * StatCalc.dexFactor(100)
		T.expect(math.abs(bare.values.critChance - rated) < 1e-6).toBe(true)
		T.expect(StatCalc.dexFactor(100) < 1).toBe(true)
		local flat: { [string]: number }, pct: { [string]: number } = {}, {}
		for _, item in sp.items do
			local itemStats = ItemRoll.itemStats(item)
			for id, v in itemStats.flat do
				flat[id] = (flat[id] or 0) + v
			end
			for id, v in itemStats.pct do
				pct[id] = (pct[id] or 0) + v
			end
		end
		local weapon = sp.p.weaponSpeed and ItemRoll.itemStats(sp.items[1]).weapon
		local full = StatCalc.compute({
			level = 100,
			stats = sp.stats,
			sources = {
				{ key = "gear", flat = flat, pct = pct },
				{ key = "passives", flat = sp.passives.flat, pct = sp.passives.pct },
			},
			weapon = if weapon
				then { dmg = weapon.dmg, mdmg = weapon.mdmg, speed = weapon.speed, ranged = weapon.ranged }
				else nil,
		})
		T.expect(math.abs(full.values.critChance - sp.p.values.critChance) < 1e-9).toBe(true)
	end)

	T.it("player: the element of opts.gear stays when opts.element is not given", function()
		local mage = SkillModel.builds("Mage")[1]
		T.expect(SkillModel.player(mage, 45, { gear = { element = "ice" } :: any }).element).toBe("ice")
		T.expect(SkillModel.player(mage, 45, { element = "fire", gear = { element = "ice" } :: any }).element)
			.toBe("fire")
	end)

	T.it("compatibility: playerFromItems without extra unchanged; T-SK numbers at L45 finite", function()
		for _, classId in B.CLASSES do
			local items = B.gear(classId, 45)
			local plain = B.playerFromItems(classId, 45, items)
			local empty = B.playerFromItems(classId, 45, items, nil, {})
			local same = B.playerFromItems(classId, 45, items, nil, { stats = B.statsFor(classId, 45) })
			for id, v in plain.values do
				if empty.values[id] ~= v or same.values[id] ~= v then
					error(`{classId} {id}: {v} / {empty.values[id]} / {same.values[id]}`, 0)
				end
			end
			for _, build in SkillModel.builds(classId) do
				local m = SkillModel.metrics(build, 45)
				for _, v in { m.basic, m.onCooldown, m.burst8, m.sustained60, m.aoe3burst, m.tsk1, m.tsk2, m.tsk3 } do
					if not finite(v) or v <= 0 then
						error(`{classId} {build.key}: not finite`, 0)
					end
				end
				if classId == "Mage" then
					T.expect(finite(m.tsk4) and m.tsk4 > 0).toBe(true)
				end
				if classId == "Cleric" then
					T.expect(finite(SkillModel.oneHeal(build, 45))).toBe(true)
					T.expect(finite(SkillModel.oneHeal(build, 45, SkillModel.defenderTank(45)))).toBe(true)
					T.expect(finite(SkillModel.healerVsBoss(build, "morvane").tsk6)).toBe(true)
				end
				for _, text in m.unmodelled do
					T.expect(type(text)).toBe("string")
				end
			end
		end
	end)
end)

-- Class mechanics and path targets (S86) -------------------------------------------------------------------------
-- tests/SkillModel.luau: each class mechanic on a case computed by hand from the data (the numbers come from the
-- game's functions in the test, never from the model), its edge case, Monte Carlo of Logic/Roll for the dice, the
-- text guards of the server-only constants, the block against FightSim.hit, the control of lines and stat traits
-- against FightSim.dps, the cross test of the traits on the event against traitTerms with the measured situation.

local Channel = require("../src/shared/Logic/Channel")
local EffectStack = require("../src/shared/Logic/EffectStack")
local Intercept = require("../src/shared/Logic/Intercept")
local ItemTraits = require("../src/shared/Data/ItemTraits")
local PathData = require("../src/shared/Data/Paths")
local Roll = require("../src/shared/Logic/Roll")
local Combat = require("../src/shared/Data/Combat")
local BuffCategories = require("../src/shared/Data/BuffCategories")
local Damage = require("../src/shared/Logic/Damage")
local SkillMotions = require("../src/shared/Data/SkillMotions")

local function near1(a: number, b: number, rel: number?): boolean
	return math.abs(a - b) <= (rel or 0.01) * math.max(1e-9, math.abs(b))
end

-- A build variant with only `skillId` in the rotation (and an optional def override).
local function only(build: SkillModel.Build, skillId: string, extra: { [string]: any }?): SkillModel.Build
	local changes: { [string]: any } = { rotation = { { skill = skillId } } }
	for k, v in extra or {} do
		changes[k] = v
	end
	return variant(build, `test.only.{build.key}.{skillId}`, changes)
end

-- The step times of the basic swings of a fight (each new state.lastSwing), and the swing interval at the start.
local function swingTimes(sp: any, opts: { [string]: any }): { number }
	local times: { number } = {}
	local last: any = nil
	local o = table.clone(opts)
	o.sample = function(state: any)
		if state.lastSwing ~= last then
			last = state.lastSwing
			table.insert(times, state.t)
		end
	end
	SkillModel.fight(sp, o)
	return times
end

-- No two swings closer than the interval (less one step): a swing missed in a channel is lost, not caught up
-- (CombatService.tryBasicAttack: nextAttack = now + 1 / speed).
local function noCatchUp(times: { number }, interval: number): boolean
	for i = 2, #times do
		if times[i] - times[i - 1] < interval - SkillModel.ASSUMPTIONS.dt - 1e-9 then
			return false
		end
	end
	return true
end

local function effective(sp: any, skillId: string): (any, any, number)
	local rank = Paths.skillRank(sp.character, skillId)
	local def, bp = Paths.effectiveFor(sp.character, skillId, sp.weapons, rank)
	return def, bp, rank
end

T.describe("SkillModel: class mechanics (S86)", function()
	T.it("text guards: the server-only constants of the model equal the server files", function()
		for _, guard in SkillModel.SERVER_CONSTANTS do
			local text = fs.readFile(guard.file)
			local found = string.match(text, guard.pattern)
			if not found or tonumber(found) ~= guard.value then
				error(`{guard.file}: {guard.pattern} is {tostring(found)}, the model has {guard.value}`, 0)
			end
		end
	end)

	T.it(
		"B1 heals: Heal at L45 = Skills.healAmount x healFactor; Fortune and Healer differ by their factors",
		function()
			local tank = SkillModel.defenderTank(45)
			local function byHand(key: string): number
				local sp = SkillModel.player(SkillModel.byKey(key), 45)
				local def, _, rank = effective(sp, "heal")
				-- maxHp(tank) x healHp % + magAtk x Skills.healMul(45) x healMag %, then (1 + healPower %) x (1 + heal
				-- bonuses %) x (1 + crit share x 0.5)
				local amount = tank.values.maxHp * Skills.valueAt(def, "healHp", rank) / 100
					+ (sp.p.values.magAtk or 0) * Skills.healMul(45) * Skills.valueAt(def, "healMag", rank) / 100
				T.expect(
					near1(
						amount,
						Skills.healAmount(def, rank, "heal", tank.values.maxHp, sp.p.values.magAtk or 0, 45),
						1e-9
					)
				).toBe(true)
				local v = sp.p.values
				local bonus = (sp.pathHooks.healBonus or 0) + (sp.pathHooks.allyHealBonus or 0)
				local crit = math.clamp((v.critChance or 0) * (sp.pathHooks.healCrit or 0) / 10000, 0, 1)
				return amount
					* (1 + (v.healPower or 0) / 100)
					* (1 + bonus / 100)
					* (1 + crit * (SkillData.HEAL_CRIT_MUL - 1))
					/ tank.values.maxHp
			end
			local healer, fortune = byHand("healer.dungeon"), byHand("fortune.plunder")
			T.expect(near1(SkillModel.oneHeal(SkillModel.byKey("healer.dungeon"), 45, tank), healer, 1e-9)).toBe(true)
			T.expect(near1(SkillModel.oneHeal(SkillModel.byKey("fortune.plunder"), 45, tank), fortune, 1e-9)).toBe(true)
			T.expect(fortune < healer).toBe(true)
		end
	)

	T.it("B1 shields soak damage before HP; heals restore at most the missing HP (retaliate)", function()
		local cleric = SkillModel.builds("Cleric")[1]
		local L = 45
		local m = B.monster(B.GENERIC, L)
		local plain = SkillModel.fight(SkillModel.player(cleric, L), {
			targets = { m },
			retaliate = true,
			skills = false,
			seconds = 6,
		})
		local shielded = only(cleric, "shieldOfFaith", { rotation = { { skill = "shieldOfFaith", target = "self" } } })
		local sp = SkillModel.player(shielded, L)
		local r = SkillModel.fight(sp, { targets = { m }, retaliate = true, seconds = 6 })
		local def, _, rank = effective(sp, "shieldOfFaith")
		local shield = Skills.healAmount(def, rank, "shield", sp.p.values.maxHp, sp.p.values.magAtk or 0, L)
			* SkillModel.healFactor({ sp = sp, p = sp.p, selfDirty = false, self = { effects = {} } }, "self", true)
		-- the same blows: what the shield soaked is missing from `taken`, at most the shield's value
		local soaked = plain.taken - r.taken
		T.expect(soaked > 0).toBe(true)
		T.expect(soaked <= shield + 1e-6).toBe(true)
		T.expect(r.healEff <= (r.healTo.self or 0) + 1e-9).toBe(true)
		-- a heal on a caster at full HP restores nothing (the first step: before any blow)
		local first = SkillModel.fight(SkillModel.player(cleric, L), {
			targets = { m },
			retaliate = true,
			seconds = SkillModel.ASSUMPTIONS.dt,
		})
		T.expect(first.healEff).toBe(0)
	end)

	T.it("B2 dice: 1/3 a face, 1.3/3 with rollDouble 30 (Monte Carlo of Roll.pick), the wheel 1 + boost/3", function()
		local d = SkillModel.diceExpected(3, 0, false, 0)
		for i = 1, 3 do
			T.expect(math.abs(d[i] - 1 / 3) < 1e-12).toBe(true)
		end
		local dd = SkillModel.diceExpected(3, 30, false, 0)
		for i = 1, 3 do
			T.expect(math.abs(dd[i] - 1.3 / 3) < 1e-12).toBe(true)
		end
		local rng = Rng.new(86)
		local counts = { 0, 0, 0 }
		local n = 20000
		for _ = 1, n do
			for _, face in Roll.pick(rng, 3, 30) do
				counts[face] += 1
			end
		end
		for i = 1, 3 do
			local p = dd[i]
			local sd = math.sqrt(p * (1 - p) / n)
			T.expect(math.abs(counts[i] / n - p) <= math.max(3 * sd, 0.03 * p)).toBe(true)
		end
		local wheel = SkillModel.diceExpected(3, 0, true, 50)
		for i = 1, 3 do
			T.expect(math.abs(wheel[i] - (1 + 0.5 / 3)) < 1e-12).toBe(true)
		end
	end)

	T.it(
		"B3 burn: Brand of Light's ticks = Traits.ticks(duration) x max(1, attack x value / duration) x DotBonus",
		function()
			local inq = SkillModel.byKey("inquisitor.solo")
			local L = 45
			local sp = SkillModel.player(inq, L)
			local def, bp, rank = effective(sp, "brandOfLight")
			local burn = (def.effects :: any)[1]
			T.expect(burn.kind).toBe("burn")
			local noBurn = table.clone(def)
			noBurn.effects = {}
			local function run(d: any): number
				local b = only(inq, "brandOfLight")
				local r = SkillModel.fight(SkillModel.player(b, L), {
					targets = { B.monster(B.GENERIC, L) },
					seconds = 9,
					override = { brandOfLight = { def = d, bp = bp } },
				})
				return r.by.brandOfLight or 0
			end
			local ticks = run(def) - run(noBurn)
			local duration = Skills.scaled(def, burn.duration, rank)
			local value = Skills.valueAt(def, burn.value, rank)
			local attack = sp.p.values.magAtk * sp.speedMul
			local dot = (sp.p.hooks.dotPower or 0)
			local expected = Traits.ticks(duration)
				* math.max(1, attack * value / 100 / math.max(1, duration))
				* (1 + dot / 100)
			T.expect(near1(ticks, expected, 0.01)).toBe(true)
			-- a dying target: no tick after its death. The first target has the hit plus 1.5 ticks of HP (it dies on a
			-- tick while the burn still runs); a second, living target keeps the fight going past that death.
			local hitOnly = SkillModel.fight(SkillModel.player(only(inq, "brandOfLight"), L), {
				targets = { B.monster(B.GENERIC, L) },
				seconds = 9,
				override = { brandOfLight = { def = noBurn, bp = bp } },
			})
			local hit = (hitOnly.by.brandOfLight or 0) / math.max(1, hitOnly.casts.brandOfLight or 1)
			local tick = expected / Traits.ticks(duration)
			local weak = table.clone(B.monster(B.GENERIC, L))
			weak.maxHp = hit + 1.5 * tick
			local strong = table.clone(B.monster(B.GENERIC, L))
			strong.maxHp = 1e12
			local diedAt: number?, hpAtDeath: number?, burning = nil, nil, false
			local hpEnd = 0
			SkillModel.fight(SkillModel.player(only(inq, "brandOfLight"), L), {
				targets = { weak, strong },
				dummy = false,
				seconds = 9,
				sample = function(state: any)
					local first = state.targets[1]
					if diedAt == nil and first.hp <= 0 then
						diedAt, hpAtDeath = state.t, first.hp
						for _, e in first.effects do
							if e.kind == "burn" and e.expiresAt > state.t + 1e-6 then
								burning = true
							end
						end
					end
					hpEnd = first.hp
				end,
			})
			T.expect(diedAt ~= nil and (diedAt :: number) < 8).toBe(true)
			T.expect(burning).toBe(true) -- the burn outlived the target: the case tests the cut
			T.expect(hpEnd).toBe(hpAtDeath)
		end
	)

	T.it("B4 heal zone: Sanctuary with add.duration 2 ticks 8 times; the HP track cuts a heal at full HP", function()
		local healer = SkillModel.byKey("healer.dungeon")
		local L = 70
		local sp = SkillModel.player(healer, L)
		local rank = Paths.skillRank(sp.character, "sanctuary")
		local choices = table.clone(sp.character.path.bp)
		choices[Skills.choiceKey("sanctuary", 10)] = "a" -- 10A: add.duration = 2
		local def, bp = Skills.effective(SkillData.get("sanctuary") :: any, rank, choices)
		T.expect(Skills.scaled(def, def.duration, rank)).toBe(8)
		local tank = SkillModel.defenderTank(L)
		local b = only(healer, "sanctuary", { rotation = { { skill = "sanctuary", target = "meleeAllies" } } })
		local r = SkillModel.fight(SkillModel.player(b, L), {
			targets = { B.monster(B.GENERIC, L, "boss") },
			seconds = 10,
			heal = { tank = tank, team = 5 },
			override = { sanctuary = { def = def, bp = bp } },
		})
		local one = Skills.healAmount(def, rank, "heal", tank.values.maxHp, sp.p.values.magAtk or 0, L)
			* SkillModel.healFactor({ sp = sp, p = sp.p, selfDirty = false, self = { effects = {} } }, "tank", false)
		T.expect(math.abs((r.healTo.tank or 0) / one - SkillModel.zoneTicks(8)) < 1e-6).toBe(true)
		T.expect(SkillModel.zoneTicks(8)).toBe(8)
		-- solo on the HP track (retaliate, a monster that deals nothing): at full HP the zone's ticks reach healTo
		-- (T-SK6 counts them) but restore nothing; with 1.5 ticks of HP missing only the missing HP counts
		local selfZone = only(healer, "sanctuary", { rotation = { { skill = "sanctuary", target = "self" } } })
		local spSelf = SkillModel.player(selfZone, L)
		local harmless = table.clone(B.monster(B.GENERIC, L))
		harmless.attack = 0
		local full = SkillModel.fight(spSelf, { targets = { harmless }, seconds = 4, retaliate = true })
		T.expect((full.healTo.self or 0) > 0).toBe(true)
		T.expect(full.healEff).toBe(0)
		local maxHp = spSelf.p.values.maxHp
		local tickSelf = Skills.healAmount(def, rank, "heal", maxHp, spSelf.p.values.magAtk or 0, L)
			* SkillModel.healFactor(
				{ sp = spSelf, p = spSelf.p, selfDirty = false, self = { effects = {} } },
				"self",
				false
			)
		local missing = 1.5 * tickSelf
		local low = SkillModel.fight(
			spSelf,
			{ targets = { harmless }, seconds = 4, retaliate = true, startHp = 1 - missing / maxHp }
		)
		T.expect(low.healEff <= missing + 1e-6).toBe(true)
		T.expect(low.healEff < (low.healTo.self or 0) - 0.4 * tickSelf).toBe(true)
		T.expect(low.hpEnd > 1 - 1e-9).toBe(true)
	end)

	T.it(
		"B5 Fury: 10 stacks after 10 hits a second apart; at most 4 a second; decay after 4 s; Carnage +2 frozen",
		function()
			local rules = PathData.HOOK_RULES.fury
			local hits = {}
			for i = 0, 9 do
				table.insert(hits, i)
			end
			local trace = SkillModel.furySim(hits, 20, rules.maxStacks)
			T.expect(trace[10]).toBe(10) -- second 9: the tenth hit
			-- 4 s without a hit (to 13 s), then decayPerSecond a second: 2 lost by 14, 0 by 18
			T.expect(trace[14]).toBe(10)
			T.expect(trace[15]).toBe(10 - rules.decayPerSecond)
			T.expect(trace[19]).toBe(0)
			local fast = {}
			for i = 0, 9 do
				table.insert(fast, i * 0.1)
			end
			local burst = SkillModel.furySim(fast, 1, rules.maxStacks)
			T.expect(burst[2] <= math.ceil(1 / rules.gainInterval)).toBe(true)
			-- Carnage: + HOOK_RULES.carnage.furyGain a hit, no decay while it lasts
			local carnage = SkillModel.furySim({ 0, 1, 2 }, 10, rules.maxStacks, { 0, 10 })
			T.expect(carnage[3]).toBe(3 * PathData.HOOK_RULES.carnage.furyGain)
			T.expect(carnage[10]).toBe(3 * PathData.HOOK_RULES.carnage.furyGain)
			-- Rend at 10 stacks: the direct hit x Skills.furyMultiplier(furyDmg, 10)
			local fury = SkillModel.byKey("berserker.fury")
			local sp = SkillModel.player(fury, 70)
			local def, bp = effective(sp, "rend")
			local hitOnly = table.clone(def)
			hitOnly.effects = {}
			local plainHit = table.clone(hitOnly)
			plainHit.furyConsume = nil
			local function rendHit(d: any): number
				local r = SkillModel.fight(SkillModel.player(only(fury, "rend"), 70), {
					targets = { B.monster(B.GENERIC, 70) },
					seconds = 1,
					startFury = 10,
					override = { rend = { def = d, bp = bp } },
				})
				return r.by.rend or 0
			end
			local mul =
				Skills.furyMultiplier(Skills.valueAt(def, def.furyConsume, Paths.skillRank(sp.character, "rend")), 10)
			-- the same Fury in both fights (10 stacks); only the furyConsume multiplier differs
			T.expect(near1(rendHit(hitOnly) / rendHit(plainHit), mul, 0.01)).toBe(true)
		end
	)

	T.it(
		"B6 block: EHP = max HP / FightSim.hit without own reductions; avoidance under the cap; red zones unblocked",
		function()
			local p = SkillModel.player(SkillModel.byKey("guardian.defender"), 70).p
			local bare: any = table.clone(p)
			bare.hooks = table.clone(p.hooks)
			bare.hooks.guardPerEnemy, bare.hooks.lastStand, bare.hooks.furyGuard = 0, 0, 0
			local m = B.monster(B.GENERIC, 70)
			T.expect(near1(SkillModel.ehpOf(bare, 70, false), bare.values.maxHp / FightSim.hit(m, bare), 0.01))
				.toBe(true)
			local d, mm, b = Damage.avoidance(bare.values.dodge or 0, 0, 15, Traits.blockChance(100, false))
			T.expect(d + mm + b <= (Combat.dodgeCap + Combat.avoidBonus) / 100 + 1e-9).toBe(true)
			local noBlock: any = table.clone(bare)
			noBlock.hooks = table.clone(bare.hooks)
			noBlock.hooks.block = 0
			T.expect(FightSim.hit(m, bare, nil, nil, false)).toBe(FightSim.hit(m, noBlock, nil, nil, false))
			T.expect(FightSim.hit(m, bare) <= FightSim.hit(m, noBlock)).toBe(true)
		end
	)

	T.it(
		"B7 intercept: the per-second cap leaves the rest on the target; only monster blows; = Intercept.resolve",
		function()
			local guardHp = 1000
			local cap = guardHp * BuffCategories.caps.interceptPerSecond / 100
			local windows = {}
			local candidates = { { guard = "g", share = 30, radius = 20, distance = 5, alive = true } }
			local amount = cap * 3
			local kept1, _, moved1 = Intercept.resolve("monster", amount, candidates, windows, 0, function()
				return guardHp
			end)
			local kept2, _, moved2 = Intercept.resolve("monster", amount, candidates, windows, 0.5, function()
				return guardHp
			end)
			T.expect(math.abs(moved1 + moved2 - cap) < 1e-9).toBe(true)
			T.expect(kept1 + kept2 > 2 * amount * (1 - BuffCategories.caps.intercept / 100)).toBe(true)
			local keptPvp = Intercept.resolve("pvp", amount, candidates, {}, 0, function()
				return guardHp
			end)
			T.expect(keptPvp).toBe(amount)
			local report = SkillModel.interceptReport(100)
			T.expect(report.mageKept <= report.mageHit + 1e-9).toBe(true)
			T.expect(report.wallCap <= report.wallNoCap + 1e-9).toBe(true)
		end
	)

	T.it(
		"B8 traps: a trap fires TRAP_CHECK after landing; a pull waits Push.DURATION; overlaps count once; bosses 0",
		function()
			local poacher = SkillModel.byKey("trapper.poacher")
			local L = 45
			local sp = SkillModel.player(only(poacher, "frostTrap"), L)
			local check = SkillModel.SERVER_CONSTANTS[1].value
			local pull = SkillModel.SERVER_CONSTANTS[2].value
			local delay = SkillMotions.hitDelay("frostTrap")
			local function rooted(b: SkillModel.Build, t: number): number
				return SkillModel.fight(SkillModel.player(b, L), { targets = { B.monster(B.GENERIC, L) }, seconds = t }).controlled
			end
			-- nothing before the first check, control right after it
			T.expect(rooted(only(poacher, "frostTrap"), delay + check - 0.06)).toBe(0)
			T.expect(rooted(only(poacher, "frostTrap"), delay + check + 0.3) > 0).toBe(true)
			local snare = only(poacher, "venomSnare")
			local sDef, sBp = effective(SkillModel.player(snare, L), "venomSnare")
			T.expect(Skills.pullRadius(sDef, sBp) > 0).toBe(true)
			local sDelay = SkillMotions.hitDelay("venomSnare")
			T.expect(rooted(snare, sDelay + check + pull - 0.06)).toBe(0)
			T.expect(sp.p ~= nil).toBe(true)
			-- control share is a union of the windows (never above 1); a boss takes no notBoss root
			local m = SkillModel.metrics(SkillModel.byKey("trapper.poisoner"), 100)
			T.expect(m.controlled <= 1 + 1e-9).toBe(true)
			local field = only(SkillModel.byKey("trapper.poacher"), "snarefield")
			local onBoss = SkillModel.fight(SkillModel.player(field, 70), {
				targets = { B.monster(B.GENERIC, 70, "boss") },
				seconds = 10,
			})
			T.expect(onBoss.controlled).toBe(0)
			T.expect(SkillModel.trapCatch(1, 3)).toBe(3)
			T.expect(SkillModel.trapCatch(2, 1)).toBe(0)
		end
	)

	T.it(
		"B9 falcon: strikes in 15 s from interval x (1 - falconInterval) and delay; the strongest enemyWeak only",
		function()
			local scout = SkillModel.byKey("scout.partyHunter")
			local L = 70 -- the falcon's node (row 4) is bought after 45 in this build
			local b = only(scout, "falcon")
			local sp = SkillModel.player(b, L)
			local def = effective(sp, "falcon")
			local interval = SkillModel.falconInterval(def, sp.p.hooks.falconInterval or 0)
			T.expect(interval).toBe(
				math.max(
					PathData.HOOK_RULES.royalFalcon.minInterval,
					(def.interval or 2) * (1 - (sp.p.hooks.falconInterval or 0) / 100)
				)
			)
			local r = SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, L) }, seconds = 15 })
			local duration = Skills.scaled(def, def.duration, Paths.skillRank(sp.character, "falcon"))
				+ (sp.p.hooks.falconBond or 0)
			local delay = SkillMotions.hitDelay("falcon")
			local expected = 0
			local t = (def.delay or 1)
			while t < duration - 1e-9 and delay + t < 15 - 1e-9 do
				expected += 1
				t += interval
			end
			T.expect(r.falconStrikes).toBe(expected)
			-- two vulnerabilities on one target: the hit takes the strongest (StatusEffectService.Max)
			local entries = {
				{ category = "enemyWeak", value = 8, at = 0 },
				{ category = "enemyWeak", value = 5, at = 1 },
			}
			T.expect(EffectStack.value(entries, "enemyWeak")).toBe(8)
		end
	)

	T.it(
		"B10 aiming: no basic attack while aiming, cost at the start; damage never stops it, moving refunds",
		function()
			local kingslayer = SkillModel.byKey("marksman.kingslayer")
			local L = 100
			local b = only(kingslayer, "heartseeker")
			local sp = SkillModel.player(b, L)
			local def, _, rank = effective(sp, "heartseeker")
			local castTime = def.castTime :: number
			local r = SkillModel.fight(
				sp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = castTime - 0.06, unlimited = true }
			)
			local interval = 1 / math.max(0.2, sp.p.values.atkSpeed or 1)
			local swing =
				SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, L) }, seconds = interval, skills = false })
			-- the swing at t = 0 lands before the cast; none during the aim (the end-of-window fix counts none either)
			T.expect(r.basicDealt <= swing.dealt * (1 + 1e-6)).toBe(true)
			T.expect(r.basicDealt > 0).toBe(true)
			T.expect(near1(r.spent, SkillModel.costWith(sp, def, rank, 0), 1e-9)).toBe(true)
			-- after the aim the swings start a new cadence: none caught up
			local times = swingTimes(
				sp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = castTime + 4 * interval, unlimited = true }
			)
			T.expect(#times >= 3).toBe(true)
			T.expect(noCatchUp(times, interval)).toBe(true)
			local hit = SkillModel.fight(
				sp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = castTime + 1, retaliate = true }
			)
			T.expect((hit.by.heartseeker or 0) > 0).toBe(true)
			local stop, refund = Channel.stops("castTime", "move", def)
			T.expect(stop and refund).toBe(true)
			T.expect((Channel.stops("castTime", "damage", def))).toBe(false)
		end
	)

	T.it(
		"B11 beam: the sum follows beamTickPct, mana drains per tick and ends the beam; damage does not stop it",
		function()
			local arc = SkillModel.byKey("arcanist.arcanistBoss")
			local L = 100
			local b = only(arc, "arcaneTorrent")
			-- lightning: on one target the weapon element adds nothing to the ticks (fire would burn, ice chill); the
			-- runestaff's Runic Seal off (it lights after 1.5 s of standing and would raise the later ticks)
			local sp =
				SkillModel.player(b, L, { element = "lightning", gear = { traitScale = { runicSeal = 0 } } :: any })
			local def, _, rank = effective(sp, "arcaneTorrent")
			local ticks = Skills.beamTicks(def)
			local interval = def.interval or 0.5
			local seconds = ticks * interval + 0.2
			local r =
				SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, L) }, seconds = seconds, unlimited = true })
			T.expect(r.beamTicks).toBe(ticks)
			local swing = 1 / math.max(0.2, sp.p.values.atkSpeed or 1)
			local times = swingTimes(
				sp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = seconds + 4 * swing, unlimited = true }
			)
			T.expect(#times >= 3).toBe(true)
			T.expect(noCatchUp(times, swing)).toBe(true)
			local drain = Skills.drain(
				def,
				rank,
				r.poolMax,
				{ costReduce = sp.p.values.costReduce or 0, hooks = sp.pathHooks, charges = 0 }
			)
			T.expect(near1(r.spent, drain * ticks, 1e-6)).toBe(true)
			local dmg, growth = Skills.valueAt(def, "dmg", rank), Skills.valueAt(def, "growth", rank)
			local first = SkillModel.fight(
				sp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = interval + 0.05, unlimited = true }
			)
			local series = 0
			for n = 1, ticks do
				series += Skills.beamTickPct(dmg, growth, n) / Skills.beamTickPct(dmg, growth, 1)
			end
			-- charges and empowered stay at their start for the whole beam (the cast's snapshot); no other hit
			T.expect(near1((r.by.arcaneTorrent or 0) / (first.by.arcaneTorrent or 1), series, 0.02)).toBe(true)
			local short = SkillModel.fight(
				sp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = seconds, startPool = drain * 2.5 / r.poolMax }
			)
			T.expect(short.beamTicks < ticks).toBe(true)
			local hit = SkillModel.fight(
				sp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = seconds, unlimited = true, retaliate = true }
			)
			T.expect(hit.beamTicks).toBe(ticks)
		end
	)

	T.it(
		"B12 Arcane Charges: cost with 4 = Skills.cost(charges 4); Discharge x dischargeFactor; gone after 15 s",
		function()
			local arc = SkillModel.byKey("arcanist.arcanistBoss")
			local L = 70
			local sp = SkillModel.player(arc, L, { element = "fire" })
			local def, _, rank = effective(sp, "firebolt")
			local plain = SkillModel.costWith(sp, def, rank, 0)
			local charged = SkillModel.costWith(sp, def, rank, 4)
			T.expect(near1(
				charged,
				Skills.cost(def, rank, L, "Mage", {
					costReduce = sp.p.values.costReduce or 0,
					hooks = sp.pathHooks,
					charges = 4,
				}),
				1e-12
			)).toBe(true)
			T.expect(charged > plain).toBe(true)
			local b = only(arc, "arcaneDischarge")
			local bsp = SkillModel.player(b, L, { element = "fire" })
			local dDef, _, dRank = effective(bsp, "arcaneDischarge")
			local function discharge(k: number): number
				return SkillModel.fight(bsp, { targets = { B.monster(B.GENERIC, L) }, seconds = 1, startCharges = k }).by.arcaneDischarge
					or 0
			end
			local factor = Skills.dischargeFactor(Skills.valueAt(dDef, "perCharge", dRank), 4)
			T.expect(near1(discharge(4) / discharge(0), factor, 0.02)).toBe(true)
			local idle = SkillModel.fight(
				bsp,
				{ targets = { B.monster(B.GENERIC, L) }, seconds = 16, skills = false, startCharges = 4 }
			)
			T.expect(idle.chargesEnd).toBe(0)
			T.expect(Skills.chargesNow(4, 15, 10, false)).toBe(0)
		end
	)

	T.it("B13 accumulate: 100 and 100 a second apart give 200; three waves give the sum of the three", function()
		T.expect(math.abs(SkillModel.accumulateCase(100, 100, 1, 4) - 200) < 1e-6).toBe(true)
		local per = Traits.ticks(4)
		local ticks = SkillModel.timeline({
			{ t = 0, kind = "burn", duration = 4, tick = 100 / per, accumulate = true },
			{ t = 0.4, kind = "burn", duration = 4, tick = 100 / per, accumulate = true },
			{ t = 0.8, kind = "burn", duration = 4, tick = 100 / per, accumulate = true },
		}, 8)
		local sum = 0
		for _, tick in ticks do
			sum += tick[2]
		end
		T.expect(math.abs(sum - 300) < 1e-6).toBe(true)
		-- the game's function directly: a refresh adds the unpaid rest
		local tick = EffectStack.accumulate(nil, { total = 100, duration = 4, now = 0, interval = 1 })
		T.expect(math.abs(tick * EffectStack.ticksBetween(1, 4, 1) - 100) < 1e-9).toBe(true)
	end)

	T.it(
		"B14 area rule: Thunderstorm on 3 counts 3, a chain on 2 counts 2, a single bolt takes singleDamage",
		function()
			local storm: any = nil
			for _, def in SkillData.byId do
				if def.randomTarget then
					storm = def
				end
			end
			assert(storm, "no randomTarget skill")
			T.expect(Skills.areaCount(storm, 3, 1)).toBe(3)
			local chainDef = SkillData.get("chainLightning") :: any
			T.expect(Skills.areaCount(chainDef, 0, 2)).toBe(2)
			local hooks = { areaDamage = 5, singleDamage = 7, spellDamage = 0 }
			T.expect(Skills.spellBonus("single", 1, false, hooks)).toBe(7)
			T.expect(Skills.spellBonus("area", 3, false, hooks)).toBe(5)
			T.expect(Skills.spellBonus("area", 1, false, hooks)).toBe(0)
			T.expect((SkillData.get("firebolt") :: any).hits).toBe(1)
			T.expect(Skills.tag(SkillData.get("firebolt") :: any)).toBe("single")
		end
	)

	T.it("C4 control: lines and stat traits (Mythic +9) without skills give FightSim.dps within 1 %", function()
		for _, classId in B.CLASSES do
			for _, L in SkillModel.LEVELS do
				local p = B.player(classId, L, { rarity = 5, up = 9 } :: any)
				local sp = SkillModel.wrap(p)
				local m = B.monster(B.GENERIC, L)
				local model = SkillModel.fight(sp, { skills = false, control = true, targets = { m } }).dps
				local expected = FightSim.dps(p, m)
				if not near1(model, expected, 0.01) then
					error(`{classId} {L}: model {model}, FightSim.dps {expected}`, 0)
				end
			end
		end
	end)

	T.it(
		"C5 cross test: Power Lens and Full Draw on the event within 1 point of traitTerms with the measured situation",
		function()
			for _, id in { "powerLens", "fullDraw" } do
				for _, L in { 45, 70, 100 } do
					local row = SkillModel.traitRow(id, L, 1, 0)
					if math.abs(row.model - row.measured) > 0.01 then
						error(`{id} {L}: model {row.model}, traitTerms {row.measured}`, 0)
					end
				end
			end
		end
	)

	T.it("traitScale with every trait at 1 gives the same fight as no traitScale", function()
		local ones = {}
		for _, def in ItemTraits.list do
			ones[def.id] = 1
		end
		for _, classId in B.CLASSES do
			local build = SkillModel.builds(classId)[2] or SkillModel.builds(classId)[1]
			local a = SkillModel.player(build, 70, { gear = {} :: any, element = "fire" })
			local b = SkillModel.player(build, 70, { gear = { traitScale = ones } :: any, element = "fire" })
			local ra = SkillModel.fight(a, {})
			local rb = SkillModel.fight(b, {})
			T.expect(math.abs(ra.dps - rb.dps) < 1e-6 * ra.dps).toBe(true)
		end
	end)
end)

-- Balance 20-100: paths (S86) ---------------------------------------------------------------------------------------
-- PATH_TARGETS of tests/SkillModel.luau: printed with the same pass / fail as docs/BALANS.md; a class asserts its rows
-- (above 20) once PATHS_TUNED says so (S89: Cleric, Warrior; S90: Hunter, Mage). Asserted now: the shape, the
-- dependencies of the definitions and the fixture tests/fixtures/balance_paths.json with the same data.

local PATHS_TUNED = { Cleric = false, Warrior = false, Hunter = false, Mage = false }

T.describe("Balance 20-100: paths", function()
	local results = SkillModel.evaluateTargets()
	for _, classId in B.CLASSES do
		if PATHS_TUNED[classId] then
			for _, r in results do
				if r.classId == classId and r.asserted then
					T.it(`{r.build} L{r.L} {r.id}`, function()
						if not r.pass then
							error(
								`{r.build} L{r.L} {r.id} {string.format("%.3f", r.value)} not in {r.low or "-"}-{r.high or "-"} ({r.source})`,
								0
							)
						end
					end)
				end
			end
		end
		T.it(`paths {classId} (printed{if PATHS_TUNED[classId] then "" else ", not tuned"})`, function()
			local ok, all, out = 0, 0, {}
			for _, r in results do
				if r.classId == classId then
					all += 1
					if r.pass then
						ok += 1
					else
						table.insert(out, r)
					end
				end
			end
			print(`paths {classId}: {ok}/{all} w paśmie`)
			for i = 1, math.min(15, #out) do
				local r = out[i]
				print(
					`  {r.build} L{r.L} {r.id} {string.format("%.3f", r.value)} not in {r.low or "-"}-{r.high or "-"} ({r.source})`
				)
			end
			T.expect(all > 0).toBe(true)
		end)
	end

	T.it("shape: every PATH_TARGETS row has a source, a known metric and an existing build", function()
		for _, row in SkillModel.PATH_TARGETS do
			T.expect(type(row.source) == "string" and #row.source > 0).toBe(true)
			if not row.heavy then
				T.expect(SkillModel.TARGET_METRICS[row.metric] ~= nil).toBe(true)
			end
			T.expect(SkillModel.build(row.build, row.classId) ~= nil).toBe(true)
		end
		local baseAt45: { [string]: number } = {}
		for _, r in results do
			if not finite(r.value) then
				error(`{r.id} {r.build} L{r.L}: not finite`, 0)
			end
			if r.id == "all.tsk3" and r.build == "base" and r.L == 45 then
				T.expect(baseAt45[r.classId]).toBe(nil)
				baseAt45[r.classId] = r.value
			end
		end
		-- every class's "base" row is its own base (not the first class's)
		local seen: { [number]: boolean } = {}
		for _, classId in B.CLASSES do
			local v = baseAt45[classId]
			T.expect(v ~= nil).toBe(true)
			T.expect(seen[v :: number]).toBe(nil)
			seen[v :: number] = true
		end
	end)

	T.it("definitions: Furia / Furia = 1, T-SK5 > 0, support = 4 x (1 + B) + S, mean Fury <= furyMax", function()
		local fury = SkillModel.byKey("berserker.fury")
		local commander = SkillModel.byKey("standard.commander")
		for _, L in SkillModel.METRIC_LEVELS do
			local row = { metric = "single60/fury", build = "berserker.fury", levels = { L } } :: any
			T.expect(math.abs(SkillModel.TARGET_METRICS["single60/fury"](row, L) - 1) < 1e-12).toBe(true)
			T.expect(SkillModel.oneHeal(SkillModel.byKey("healer.dungeon"), L, SkillModel.defenderTank(L)) > 0)
				.toBe(true)
			local s = SkillModel.standardSupport(commander, L)
			T.expect(math.abs(s.value - (4 * (1 + s.B) + s.S)) < 1e-12).toBe(true)
			local m = SkillModel.metrics(fury, L)
			local max = SkillModel.furyMax({ p = SkillModel.player(fury, L).p, selfDirty = false })
			T.expect(m.furyMean <= max + 1e-9 and m.furyMeanGroup <= max + 1e-9).toBe(true)
		end
	end)

	T.it("fixture: the S86 tables equal tests/fixtures/balance_paths.json while the data is the same", function()
		local values = BalanceTables.values(BalanceTables.tablesPaths())
		local fixture = BalanceTables.readPathsFixture()
		T.expect(fixture ~= nil).toBe(true)
		local report = BalanceTables.pathsFixtureDiff(values)
		for key, v in values do
			if not finite(v) then
				error(`{key}: not finite`, 0)
			end
		end
		if not report.sameData then
			-- S87 and later change the data: printed only (those sessions regenerate the fixture)
			print(
				`paths fixture: data changed ({table.concat(report.changedModules, ", ")}); {#report.diffs} values moved, `
					.. "regenerate with `lune run tools/balance_report.luau --fixture-paths` and note it in docs/SESJE.md"
			)
			for i = 1, math.min(10, #report.diffs) do
				local d = report.diffs[i]
				print(`  {d.key}: {d.before} → {d.after}`)
			end
			return
		end
		local problems = {}
		for _, key in report.missing do
			table.insert(problems, `missing {key}`)
		end
		for _, key in report.added do
			table.insert(problems, `new {key}`)
		end
		for _, d in report.diffs do
			table.insert(problems, `{d.key}: {d.before} → {d.after}`)
		end
		if #problems > 0 then
			error(
				"model się zmienił przy tych samych danych: sprawdź zmianę albo wygeneruj `--fixture-paths` i opisz w SESJE "
					.. `({#problems}): {table.concat(problems, "; ", 1, math.min(8, #problems))}`,
				0
			)
		end
	end)
end)
