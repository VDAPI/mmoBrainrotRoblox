--!strict
-- items.json, bonuses.json, icons.json (S34). Items: every definition of Data/Items with its name (ItemName),
-- the rarities it can have (found with ItemRoll.rollItem, not listed by hand), stats for every rarity and upgrade
-- +0..+9 (ItemRoll.itemStats on a synthetic instance, ilvl = tier or level), the value a merchant pays
-- (ItemValue.value), and its sources (monster and boss Monte Carlo, shops, blacksmith, alchemy, quest rewards, the
-- fishing chest, gathering, dismantling) and, for materials, what they are used for. Bonuses: definitions, pools,
-- min-max for every tier and rarity (ItemRoll.rollBonusValue with roll 0 and 1) and how often each bonus appears
-- (Monte Carlo of ItemRoll.rollItem). Icons: only after S35 (Logic/ItemIcons).

local Bonuses = require("../../src/shared/Data/Bonuses")
local Clean = require("./Clean")
local Elements = require("../../src/shared/Data/Elements")
local Fish = require("../../src/shared/Data/Fish")
local GatherNodes = require("../../src/shared/Data/GatherNodes")
local ItemRoll = require("../../src/shared/Logic/ItemRoll")
local ItemValue = require("../../src/shared/Logic/ItemValue")
local ItemData = require("../../src/shared/Data/Items")
local Json = require("./Json")
local Names = require("./Names")
local Rarities = require("../../src/shared/Data/Rarities")
local Recipes = require("../../src/shared/Data/Recipes")
local Rng = require("../../src/shared/Logic/Rng")
local Schema = require("./Schema")
local StubRng = require("./StubRng")
local UpgradeLogic = require("../../src/shared/Logic/Upgrade")
local CraftData = require("../../src/shared/Data/Crafting")

local S = Schema
local arr, map, rec, enum = S.arr, S.map, S.rec, S.enum

local Items = {}

Items.UPS = 10 -- +0..+9
Items.BONUS_TIER_ROLLS = 10000

local Weapon = rec("ItemWeapon", {
	dmg = arr("int"),
	mdmg = arr("int"),
	speed = "number",
	ranged = "bool",
	twoHanded = "bool",
})

local IconLayer = rec("IconLayer", { image = "int", x = "int", y = "int", ["tint?"] = "color" })

local Sources = rec("ItemSources", {
	monsters = arr(rec("SourceMonster", { monster = "ref:monsters", variant = "string", chance = "number" })),
	bosses = arr(rec("SourceBoss", { boss = "ref:bosses", chance = "number", personal = "bool" })),
	shops = arr(rec("SourceShop", { shop = "ref:shops", gold = "int", ["ilvl?"] = "int" })),
	crafting = arr(rec("SourceCraft", { recipe = "string", level = "int", gold = "int" })),
	alchemy = arr("string"),
	quests = arr(rec("SourceQuest", { quest = "string", n = "int" })),
	fishing = arr(rec("SourceFish", { spot = "string", chance = "number" })),
	fishingChest = "bool",
	gathering = arr(rec("SourceGather", { node = "string", chance = "number", min = "int", max = "int" })),
	dismantle = "bool",
})

S.file(
	"items",
	rec("ItemsFile", {
		items = arr(rec("Item", {
			id = "string",
			category = enum("Category"),
			type = "string",
			["slot?"] = enum("SlotGroup"),
			["classes?"] = arr(enum("ClassId")),
			level = "int",
			["tier?"] = "int",
			name = "name",
			["nameByElement?"] = map("name"),
			["desc?"] = "name",
			glyph = "string",
			color = "color",
			["iconKey?"] = "string",
			["layers?"] = arr(IconLayer),
			["layersByElement?"] = map(arr(IconLayer)),
			bind = "bool",
			stackable = "bool",
			maxStack = "int",
			elemental = "bool",
			["capacity?"] = "int",
			["use?"] = "data",
			["bonusGroup?"] = "string",
			["fixedBonuses?"] = arr(rec("FixedBonus", { stat = "ref:bonuses", v = "number" })),
			["boss?"] = "ref:bosses",
			noSell = "bool",
			rarities = arr(enum("RarityKey")),
			requiredLevel = "int",
			["stats?"] = map(rec("ItemRarityStats", { base = map(arr("number")), ["weapon?"] = Weapon })),
			value = map(arr("int")),
			sources = Sources,
			["usedFor?"] = rec("ItemUsedFor", {
				upgrade = arr("int"),
				crafting = "int",
				alchemy = arr("string"),
			}),
		})),
		slots = map(rec("SlotInfo", { name = "name" })),
		categories = map(rec("CategoryInfo", { name = "name" })),
		bases = map(rec("BaseInfo", {
			name = "name",
			slot = enum("SlotGroup"),
			["classes?"] = arr(enum("ClassId")),
			elemental = "bool",
			bonusGroup = "string",
			glyph = "string",
		})),
	})
)

S.file(
	"bonuses",
	rec("BonusesFile", {
		bonuses = arr(rec("Bonus", {
			id = "string",
			name = "name",
			["stat?"] = "string",
			mode = "string",
			["hook?"] = "string",
			percent = "bool",
			decimals = "int",
			scaling = "string",
			min = "number",
			max = "number",
			ranges = map(map(arr("number"))),
		})),
		pools = map(arr("ref:bonuses")),
		frequency = map(map(map("number"))),
		classStats = map(arr(enum("ClassId"))),
		rolls = "int",
	})
)

S.file(
	"icons",
	rec("IconsFile", {
		cell = "number",
		tierTint = "data",
		icons = "data",
		sheets = arr("string"),
	})
)

local function rarityKey(id: number): string
	return Rarities.get(id).key
end

-- Rarities an item can have: every source rarity (+ Common) passed through ItemRoll.rollItem.
function Items.allowedRarities(def: any): { number }
	if def.category ~= "equipment" then
		return { def.rarity or Rarities.COMMON }
	end
	local set: { [number]: boolean } = {}
	local candidates: { [number]: boolean } = { [Rarities.COMMON] = true, [Rarities.MYTHIC] = true }
	for _, weights in Rarities.dropWeights do
		for r in weights do
			candidates[r] = true
		end
	end
	for _, r in Clean.keys(candidates) do
		local item = ItemRoll.rollItem(def.id, def.tier or def.level, r, Rng.new(1), "wiki")
		set[item.rarity] = true
	end
	return Clean.keys(set)
end

local function instance(def: any, rarity: number, up: number, element: string?): any
	return {
		uid = "wiki",
		id = def.id,
		ilvl = def.tier or def.level,
		rarity = rarity,
		up = up,
		bonuses = {},
		bound = false,
		n = 1,
		el = element,
	}
end

local function statsFor(def: any, rarity: number): any
	local base: { [string]: { number } } = {}
	local weapon = nil
	for up = 0, Items.UPS - 1 do
		local s = ItemRoll.itemStats(instance(def, rarity, up))
		for _, stat in Clean.keys(s.base) do
			base[stat] = base[stat] or {}
			table.insert(base[stat], s.base[stat])
		end
		if s.weapon then
			weapon = weapon
				or {
					dmg = {},
					mdmg = {},
					speed = s.weapon.speed,
					ranged = s.weapon.ranged,
					twoHanded = s.weapon.twoHanded,
				}
			table.insert(weapon.dmg, s.weapon.dmg)
			table.insert(weapon.mdmg, s.weapon.mdmg)
		end
	end
	return { base = Json.object(base), weapon = weapon }
end

local function valuesFor(def: any, rarity: number): { number }
	local out = {}
	local ups = if def.category == "equipment" then Items.UPS - 1 else 0
	for up = 0, ups do
		table.insert(out, ItemValue.value(instance(def, rarity, up), def))
	end
	return out
end

-- Upgrade steps that need a material, and alchemy / blacksmith recipes using it.
local function usedForIndex(): { [string]: any }
	local out: { [string]: any } = {}
	local function entry(id: string): any
		out[id] = out[id] or { upgrade = {}, crafting = 0, alchemy = {} }
		return out[id]
	end
	for _, r in Rarities.list do
		for n = 1, UpgradeLogic.MAX do
			local cost = UpgradeLogic.cost(
				{
					uid = "wiki",
					id = "sword1h_1",
					rarity = r.id,
					ilvl = 1,
					bonuses = {},
					up = n - 1,
					bound = false,
					n = 1,
				} :: any,
				n
			)
			for _, m in cost.materials do
				local e = entry(m.id)
				if not table.find(e.upgrade, n) then
					table.insert(e.upgrade, n)
				end
			end
		end
	end
	for _, recipe in CraftData.list do
		for _, m in recipe.materials do
			entry(m.id).crafting += 1
		end
	end
	for _, recipe in Recipes.list do
		for _, ing in recipe.ingredients do
			local e = entry(ing.id)
			if not table.find(e.alchemy, recipe.id) then
				table.insert(e.alchemy, recipe.id)
			end
		end
	end
	for _, e in out do
		table.sort(e.upgrade)
		table.sort(e.alchemy)
	end
	return out
end

local function sourcesFor(
	ctx: any,
	id: string,
	dismantled: { [string]: boolean },
	fishSpots: { [string]: any },
	gather: { [string]: any }
): any
	local monsters = {}
	for _, s in ctx.drops[id] or {} do
		table.insert(monsters, s)
	end
	local alchemy = {}
	for _, recipe in Recipes.list do
		if recipe.result.id == id then
			table.insert(alchemy, recipe.id)
		end
	end
	local chest = false
	for _, entry in Fish.CHEST_LOOT do
		chest = chest or entry.id == id
	end
	return {
		monsters = monsters,
		bosses = ctx.bossDrops[id] or {},
		shops = ctx.shopItems and ctx.shopItems[id] or {},
		crafting = ctx.crafted and ctx.crafted[id] or {},
		alchemy = alchemy,
		quests = ctx.questItems and ctx.questItems[id] or {},
		fishing = fishSpots[id] or {},
		fishingChest = chest,
		gathering = gather[id] or {},
		dismantle = dismantled[id] == true,
	}
end

local function sortedDefs(): { any }
	local list = {}
	for _, def in ItemData.byId do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

function Items.build(ctx: any): any
	local ItemIcons = if ctx.features.itemIcons then (require :: any)("../../src/shared/Logic/ItemIcons") else nil
	local used = usedForIndex()
	local dismantled: { [string]: boolean } = {}
	for _, r in Rarities.list do
		for _, d in r.dismantle do
			dismantled[d.id] = true
		end
	end
	local fishSpots: { [string]: any } = {}
	for _, spotId in Clean.keys(Fish.spots) do
		local spot = Fish.spots[spotId]
		local total = 0
		for _, f in spot.fish do
			total += f.weight
		end
		for _, f in spot.fish do
			fishSpots[f.id] = fishSpots[f.id] or {}
			table.insert(fishSpots[f.id], { spot = spotId, chance = f.weight / total })
		end
	end
	local gather: { [string]: any } = {}
	for _, nodeId in Clean.keys(GatherNodes.kinds) do
		for _, l in GatherNodes.kinds[nodeId].loot do
			gather[l.id] = gather[l.id] or {}
			table.insert(gather[l.id], { node = nodeId, chance = l.chance, min = l.min, max = l.max })
		end
	end

	local list = {}
	for _, def in sortedDefs() do
		if not ctx.hidden[def.id] then
			local rarities = Items.allowedRarities(def)
			local keys = {}
			local stats = nil
			local value = {}
			for _, r in rarities do
				table.insert(keys, rarityKey(r))
				value[rarityKey(r)] = valuesFor(def, r)
				if def.category == "equipment" then
					stats = stats or {}
					stats[rarityKey(r)] = statsFor(def, r)
				end
			end
			local nameByElement = nil
			if def.elemental then
				nameByElement = {}
				for _, el in Elements.WEAPON do
					nameByElement[el] = Names.item(def.id, el)
				end
			end
			local usedFor = used[def.id]
			-- S35: atlas icon (Logic/ItemIcons.resolve); mage weapons once per weapon element.
			local iconKey, layers, layersByElement = nil, nil, nil
			if ItemIcons then
				local resolved = ItemIcons.resolve(def)
				if resolved then
					iconKey, layers = resolved.key, resolved.layers
				end
				if def.elemental then
					layersByElement = {}
					for _, el in Elements.WEAPON do
						local r = ItemIcons.resolve(def, el)
						if r then
							layersByElement[el] = r.layers
						end
					end
				end
			end
			table.insert(list, {
				id = def.id,
				category = def.category,
				type = def.type,
				slot = def.slot,
				classes = if def.classes then Clean.clean(def.classes) else nil,
				level = def.level,
				tier = def.tier,
				name = Names.item(def.id),
				nameByElement = nameByElement,
				desc = Names.opt(def.descKey),
				glyph = def.icon.glyph,
				color = def.icon.color,
				iconKey = iconKey,
				layers = layers,
				layersByElement = layersByElement,
				bind = def.bindOnPickup == true,
				stackable = def.stackable,
				maxStack = def.maxStack,
				elemental = def.elemental == true,
				capacity = def.capacity,
				use = if def.use then Clean.clean(def.use) else nil,
				bonusGroup = def.bonusGroup,
				fixedBonuses = if def.fixedBonuses then Clean.clean(def.fixedBonuses) else nil,
				boss = def.bossId,
				noSell = def.noSell == true,
				rarities = keys,
				requiredLevel = ItemRoll.requiredLevel(instance(def, rarities[1], 0)),
				stats = stats,
				value = value,
				sources = sourcesFor(ctx, def.id, dismantled, fishSpots, gather),
				usedFor = if usedFor and (#usedFor.upgrade > 0 or usedFor.crafting > 0 or #usedFor.alchemy > 0)
					then usedFor
					else nil,
			})
		end
	end

	local slots = {}
	for _, group in Clean.keys(ItemData.slotGroup) do
		local slotGroup = ItemData.slotGroup[group]
		if not slots[slotGroup] then
			slots[slotGroup] = { name = Names.of(if slotGroup == "ring" then "slot.ring1" else `slot.{slotGroup}`) }
		end
	end
	local categories = {}
	for _, def in ItemData.byId do
		categories[def.category] = categories[def.category] or { name = Names.of(`category.{def.category}`) }
	end
	local bases = {}
	for _, base in ItemData.bases.list do
		bases[base.type] = {
			name = Names.of(`itemBase.{base.type}`),
			slot = base.slot,
			classes = if base.classes then Clean.clean(base.classes) else nil,
			elemental = base.elemental == true,
			bonusGroup = base.bonusGroup,
			glyph = base.glyph,
		}
	end
	return { items = list, slots = slots, categories = categories, bases = bases }
end

-- A representative item of a bonus pool (middle tier) for the frequency Monte Carlo.
local function sampleOf(pool: string): any
	local best = nil
	for _, def in sortedDefs() do
		if def.bonusGroup == pool and def.tier and not def.fixedBonuses and not def.classes then
			if not best or math.abs(def.tier - 50) < math.abs(best.tier - 50) then
				best = def
			end
		end
	end
	if best then
		return best
	end
	for _, def in sortedDefs() do
		if def.bonusGroup == pool and def.tier and not def.fixedBonuses then
			if not best or math.abs(def.tier - 50) < math.abs(best.tier - 50) then
				best = def
			end
		end
	end
	return best
end

function Items.bonuses(ctx: any): any
	local tiers = ItemData.bases.tiers
	local list = {}
	for _, id in Clean.keys(Bonuses.byId) do
		local b = Bonuses.byId[id]
		local ranges = {}
		for _, tier in tiers do
			local byRarity = {}
			for _, r in Rarities.list do
				byRarity[r.key] =
					{ ItemRoll.rollBonusValue(id, tier, r.id, 0), ItemRoll.rollBonusValue(id, tier, r.id, 1) }
			end
			ranges[tostring(tier)] = byRarity
		end
		table.insert(list, {
			id = id,
			name = Names.of(b.nameKey),
			stat = b.stat,
			mode = b.mode,
			hook = b.hook,
			percent = b.percent,
			decimals = b.decimals,
			scaling = b.scaling,
			min = b.min,
			max = b.max,
			ranges = ranges,
		})
	end
	-- How often each bonus appears on a rolled item of a pool and rarity (Monte Carlo, fixed seed per pool).
	local rolls = math.min(Items.BONUS_TIER_ROLLS, ctx.rolls)
	local frequency = {}
	for _, pool in Clean.keys(Bonuses.pools) do
		local sample = sampleOf(pool)
		if sample then
			local byRarity = {}
			for _, r in Rarities.list do
				if r.bonusMax > 0 or r.legendaryLines > 0 then
					local rng = Rng.new(StubRng.seedOf(`bonus:{pool}:{r.key}`))
					local counts: { [string]: number } = {}
					for _ = 1, rolls do
						local item = ItemRoll.rollItem(sample.id, sample.tier, r.id, rng, "wiki")
						for _, bonus in item.bonuses do
							counts[bonus.stat] = (counts[bonus.stat] or 0) + 1
						end
					end
					local shares = {}
					for _, stat in Clean.keys(counts) do
						shares[stat] = counts[stat] / rolls
					end
					byRarity[r.key] = shares
				end
			end
			frequency[pool] = byRarity
		end
	end
	local classStats = {}
	for _, id in Clean.keys(Bonuses.classStats) do
		classStats[id] = Clean.clean(Bonuses.classStats[id])
	end
	return {
		bonuses = list,
		pools = Clean.clean(Bonuses.pools),
		frequency = frequency,
		classStats = classStats,
		rolls = rolls,
	}
end

-- icons.json after S35 (Data/ItemIconAtlas); atlas paths only, never asset ids.
function Items.icons(ctx: any): any
	if not ctx.features.itemIconAtlas then
		return nil
	end
	local Atlas = (require :: any)("../../src/shared/Data/ItemIconAtlas")
	local sheets = {}
	for i = 1, Atlas.SHEETS do
		table.insert(sheets, `art/icons/items_{i}.png`)
	end
	return {
		cell = Atlas.CELL,
		tierTint = Clean.clean(Atlas.TIER_TINT),
		icons = Clean.clean(Atlas.ICONS),
		sheets = sheets,
	}
end

-- Enums of items.json.
function Items.registerEnums()
	local categories, slots = {}, {}
	for _, def in ItemData.byId do
		categories[def.category] = true
		if def.slot then
			slots[def.slot] = true
		end
	end
	Schema.setEnum("Category", Clean.keys(categories))
	Schema.setEnum("SlotGroup", Clean.keys(slots))
end

return Items
