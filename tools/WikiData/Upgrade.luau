--!strict
-- upgrade.json (S34): the blacksmith's steps +1..+9 (Upgrade.chance as a fraction, Upgrade.statMultiplier, the
-- level after a failure without and with the protection scroll read from Upgrade.attempt with a failing StubRng)
-- and the cost of every step for every equipment tier and rarity (Upgrade.cost: ilvl = tier). Field names are a
-- contract for the calculator (S40).

local Clean = require("./Clean")
local Items = require("../../src/shared/Data/Items")
local Rarities = require("../../src/shared/Data/Rarities")
local Schema = require("./Schema")
local StubRng = require("./StubRng")
local Rng = require("../../src/shared/Logic/Rng")
local UpgradeLogic = require("../../src/shared/Logic/Upgrade")

local S = Schema
local arr, map, rec = S.arr, S.map, S.rec

local Upgrade = {}

Upgrade.PROTECTION = "scroll_protection"

local Cost =
	rec("UpgradeCost", { gold = "int", materials = arr(rec("UpgradeMaterial", { id = "ref:items", n = "int" })) })

S.file(
	"upgrade",
	rec("UpgradeFile", {
		max = "int",
		steps = arr(rec("UpgradeStep", {
			to = "int",
			chance = "number",
			statMultiplier = "number",
			["failTo?"] = "int",
			protectedTo = "int",
		})),
		tiers = arr("int"),
		costs = map(map(arr(Cost))),
		protection = "ref:items",
		vectors = arr(rec("UpgradeVector", {
			from = "int",
			to = "int",
			["protectFrom?"] = "int",
			ilvl = "int",
			rarity = "string",
			runs = "int",
			attempts = "number",
			gold = "number",
			materials = map("number"),
			scrolls = "number",
		})),
	})
)

local function instance(ilvl: number, rarity: number, up: number): any
	return { uid = "wiki", id = "sword1h_1", rarity = rarity, ilvl = ilvl, bonuses = {}, up = up, bound = false, n = 1 }
end

-- Calculator check vectors (S40): the mean attempts, gold, materials and protection scrolls of upgrading from
-- `from` to `to` (scrolls on every attempt at a target >= protectFrom), simulated with Upgrade.attempt and the
-- Upgrade.cost paid before each attempt, like BlacksmithService. The wiki's Markov chain must match them.
Upgrade.VECTOR_RUNS = 20000
Upgrade.VECTOR_CASES = {
	{ from = 0, to = 9, ilvl = 30, rarity = "legendary" },
	{ from = 5, to = 8, protectFrom = 7, ilvl = 30, rarity = "legendary" },
	{ from = 0, to = 5, ilvl = 30, rarity = "legendary" },
}

function Upgrade.simulate(case: any, runs: number): any
	local rarity = Rarities.list[1].id
	for _, r in Rarities.list do
		if r.key == case.rarity then
			rarity = r.id
		end
	end
	local rng = Rng.new(4021 + case.from * 100 + case.to * 10 + (case.protectFrom or 0))
	local attempts, gold, scrolls = 0, 0, 0
	local materials: { [string]: number } = {}
	for _ = 1, runs do
		local up = case.from
		while up < case.to do
			local item = instance(case.ilvl, rarity, up)
			local cost = UpgradeLogic.cost(item, up + 1)
			gold += cost.gold
			for _, m in cost.materials do
				materials[m.id] = (materials[m.id] or 0) + m.n
			end
			local protect = case.protectFrom ~= nil and up + 1 >= case.protectFrom
			if protect then
				scrolls += 1
			end
			attempts += 1
			up = UpgradeLogic.attempt(item, protect, rng).to
		end
	end
	local mean = {}
	for id, n in materials do
		mean[id] = n / runs
	end
	return {
		from = case.from,
		to = case.to,
		protectFrom = case.protectFrom,
		ilvl = case.ilvl,
		rarity = case.rarity,
		runs = runs,
		attempts = attempts / runs,
		gold = gold / runs,
		materials = mean,
		scrolls = scrolls / runs,
	}
end

-- Equipment tiers of the generated items (1, 5, 10, ..., 100), sorted.
function Upgrade.tiers(): { number }
	local set: { [number]: boolean } = {}
	for _, def in Items.byId do
		if def.tier then
			set[def.tier] = true
		end
	end
	return Clean.keys(set)
end

function Upgrade.build(ctx: any): any
	local steps = {}
	for n = 1, UpgradeLogic.MAX do
		local item = instance(1, Rarities.COMMON, n - 1)
		local failed = UpgradeLogic.attempt(item, false, StubRng.new("fail"))
		local guarded = UpgradeLogic.attempt(item, true, StubRng.new("fail"))
		table.insert(steps, {
			to = n,
			chance = UpgradeLogic.chance(n) / 100,
			statMultiplier = UpgradeLogic.statMultiplier(n),
			failTo = if failed.success then nil else failed.to,
			protectedTo = if guarded.success then n else guarded.to,
		})
	end
	local tiers = Upgrade.tiers()
	local costs = {}
	for _, tier in tiers do
		local byRarity = {}
		for _, r in Rarities.list do
			local list = {}
			for n = 1, UpgradeLogic.MAX do
				local cost = UpgradeLogic.cost(instance(tier, r.id, n - 1), n)
				table.insert(list, { gold = cost.gold, materials = Clean.clean(cost.materials) })
			end
			byRarity[r.key] = list
		end
		costs[tostring(tier)] = byRarity
	end
	local vectors = {}
	local runs = math.min(Upgrade.VECTOR_RUNS, math.max(1000, (ctx and ctx.rolls) or Upgrade.VECTOR_RUNS))
	for _, case in Upgrade.VECTOR_CASES do
		table.insert(vectors, Upgrade.simulate(case, runs))
	end
	return {
		max = UpgradeLogic.MAX,
		steps = steps,
		tiers = tiers,
		costs = costs,
		protection = Upgrade.PROTECTION,
		vectors = vectors,
	}
end

return Upgrade
