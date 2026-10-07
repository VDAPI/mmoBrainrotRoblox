--!strict
-- crafting.json (S34): the blacksmith's recipes shortened (recipes with the same level, gold and materials in one
-- row with the list of items), dismantling (Dismantle.preview of a synthetic item of every rarity) and the refund of
-- upgrades +1..+9 (Dismantle.upgradeRefund). Fills ctx.crafted (item -> recipe row) for items.json.

local Clean = require("./Clean")
local CraftData = require("../../src/shared/Data/Crafting")
local Dismantle = require("../../src/shared/Logic/Dismantle")
local Rarities = require("../../src/shared/Data/Rarities")
local Schema = require("./Schema")

local S = Schema
local arr, map, rec = S.arr, S.map, S.rec

local Crafting = {}

local Amount = rec("CraftAmount", { id = "ref:items", n = "int" })
local Range = rec("CraftRange", { id = "ref:items", min = "int", max = "int" })

S.file(
	"crafting",
	rec("CraftingFile", {
		rows = arr(rec("CraftRow", {
			level = "int",
			gold = "int",
			materials = arr(Amount),
			slot = "string",
			items = arr(
				rec(
					"CraftItem",
					{ recipe = "string", item = "ref:items", ["el?"] = "string", ["classes?"] = arr("string") }
				)
			),
		})),
		dismantle = map(arr(Range)),
		refund = arr(rec("UpgradeRefund", { up = "int", materials = arr(Amount) })),
	})
)

function Crafting.build(ctx: any): any
	ctx.crafted = {}
	local rows: { [string]: any } = {}
	local order = {}
	for _, recipe in CraftData.list do
		if not ctx.hidden[recipe.item] then
			local mats = {}
			for _, m in recipe.materials do
				table.insert(mats, `{m.id}x{m.n}`)
			end
			local key = `{recipe.level}|{recipe.gold}|{recipe.slot}|{table.concat(mats, ",")}`
			local row = rows[key]
			if not row then
				row = {
					level = recipe.level,
					gold = recipe.gold,
					materials = Clean.clean(recipe.materials),
					slot = recipe.slot,
					items = {},
				}
				rows[key] = row
				table.insert(order, key)
			end
			table.insert(row.items, {
				recipe = recipe.id,
				item = recipe.item,
				el = recipe.el,
				classes = if recipe.classes then Clean.clean(recipe.classes) else nil,
			})
			ctx.crafted[recipe.item] = ctx.crafted[recipe.item] or {}
			table.insert(ctx.crafted[recipe.item], { recipe = recipe.id, level = recipe.level, gold = recipe.gold })
		end
	end
	table.sort(order, function(a, b)
		local ra, rb = rows[a], rows[b]
		if ra.level ~= rb.level then
			return ra.level < rb.level
		end
		if ra.slot ~= rb.slot then
			return ra.slot < rb.slot
		end
		return a < b
	end)
	local list = {}
	for _, key in order do
		table.insert(list, rows[key])
	end
	local dismantle = {}
	for _, r in Rarities.list do
		local item =
			{ uid = "wiki", id = "sword1h_1", rarity = r.id, ilvl = 1, bonuses = {}, up = 0, bound = false, n = 1 }
		dismantle[r.key] = Clean.clean(Dismantle.preview(item :: any))
	end
	local refund = {}
	for up = 1, 9 do
		local item = {
			uid = "wiki",
			id = "sword1h_1",
			rarity = Rarities.COMMON,
			ilvl = 1,
			bonuses = {},
			up = up,
			bound = false,
			n = 1,
		}
		local mats = {}
		for _, m in Dismantle.upgradeRefund(item :: any) do
			table.insert(mats, { id = m.id, n = m.n })
		end
		table.insert(refund, { up = up, materials = mats })
	end
	return { rows = list, dismantle = dismantle, refund = refund }
end

return Crafting
