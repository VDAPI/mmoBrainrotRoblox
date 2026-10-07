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
	})
)

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

local function instance(ilvl: number, rarity: number, up: number): any
	return { uid = "wiki", id = "sword1h_1", rarity = rarity, ilvl = ilvl, bonuses = {}, up = up, bound = false, n = 1 }
end

function Upgrade.build(_ctx: any): any
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
	return { max = UpgradeLogic.MAX, steps = steps, tiers = tiers, costs = costs, protection = Upgrade.PROTECTION }
end

return Upgrade
