--!strict
-- Balance targets, checked with the model in tests/Balance.luau (expected values from the game's own modules).
--   * S32 targets of levels 1-20 (Balance.targets1_20): a report until S91 retunes 1-20 (owner answer 4); the
--     structural checks of the S32 blocks stay asserted. The 1-20 numbers themselves: tests/balance1_20.spec.
--   * Global targets 20-100 (Balance.targetsGlobal, G1-G9, G11-G13; G7-G9 from S84): a report until S87 sets
--     GLOBAL_ASSERT.
--   * Regions (Balance.targetsRegion): asserted where Balance.TUNED says so (S83: the Meadows' kinds and Grimrok's
--     schedule only), printed elsewhere.
--   * The balance ledger (S83, balance plan 2.6): always asserted.
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
	T.it("global targets G1-G9, G11-G13 (printed)", function()
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

-- Items, loot and monster defence 20-100 (S84) --------------------------------------------------------------------
-- One case per table group: the keys of tests/fixtures/balance_items.json, finite values, the dependencies that follow
-- from the definitions, and the fixture: with the same data (dataHash) every value within its tolerance; with
-- changed data (S87 and later) the differences are only printed. Plus the S32 compatibility checks and Monte Carlo
-- on the game's functions (Logic/Rng, fixed seeds).

local AreaProfiles = require("../src/shared/Data/AreaProfiles")
local AreaRates = require("../src/shared/Logic/AreaRates")
local BalanceTables = require("./BalanceTables")
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
				if not near(mean, expected[stat], sd, n) then
					error(`{defId} {stat}: mean {mean}, expectedBonuses {expected[stat]}`, 0)
				end
			end
		end
	end)
end)
