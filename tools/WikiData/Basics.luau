--!strict
-- Small wiki data files (S34): rarities, elements, classes, stats, progression, mechanics, titles, blessings,
-- cosmetics (no prices), fish, gathering, alchemy recipes. Every number comes from src/shared/Data or a Logic
-- function; names through Names (Util/Locale).

local Blessings = require("../../src/shared/Data/Blessings")
local Classes = require("../../src/shared/Data/Classes")
local Clean = require("./Clean")
local Combat = require("../../src/shared/Data/Combat")
local Config = require("../../src/shared/Config")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local Elements = require("../../src/shared/Data/Elements")
local Exp = require("../../src/shared/Logic/Exp")
local Fish = require("../../src/shared/Data/Fish")
local GatherNodes = require("../../src/shared/Data/GatherNodes")
local Places = require("./Places")
local Items = require("../../src/shared/Data/Items")
local Names = require("./Names")
local Progression = require("../../src/shared/Data/Progression")
local Rarities = require("../../src/shared/Data/Rarities")
local Recipes = require("../../src/shared/Data/Recipes")
local Schema = require("./Schema")
local Stats = require("../../src/shared/Data/Stats")
local Titles = require("../../src/shared/Data/Titles")

local S = Schema
local arr, map, rec, enum = S.arr, S.map, S.rec, S.enum

local Basics = {}

-- Config keys the wiki may show (docs/WIKI.md §1): listed one by one, never a pattern. Never RespawnNowCost.
Basics.CONFIG_KEYS = {
	"MaxLevel",
	"CombatTimeout",
	"RespawnBase",
	"RespawnPerLevel",
	"FastRespawnMultiplier",
	"DeathChoiceTimeout",
	"RespawnShieldSeconds",
	"RespawnSearchRadius",
	"PvpToggleDelay",
	"PvpCombatLock",
	"PvpCcMultiplier",
	"PvpKillCredit",
	"DuelCountdown",
	"DuelTimeLimit",
	"DuelInviteSeconds",
	"TradeRange",
	"TradeConfirmDelay",
	"LootLifetime",
	"PotionCooldown",
	"DefaultCapacity",
}

local ZONE_COLORS_FALLBACK = { green = "#4FD16B", yellow = "#E0C23B", red = "#D64A3E" }

-- Schemas ----------------------------------------------------------------------------------------------------

local Amount = rec("Amount", { id = "ref:items", n = "int" })
local AmountRange = rec("AmountRange", { id = "ref:items", min = "int", max = "int", ["chance?"] = "number" })

S.file(
	"rarities",
	rec("RaritiesFile", {
		rarities = arr(rec("Rarity", {
			id = "int",
			key = enum("RarityKey"),
			name = "name",
			short = "name",
			color = "color",
			textColor = "color",
			bonusMin = "int",
			bonusMax = "int",
			legendaryLines = "int",
			baseMul = "number",
			rangeMul = "number",
			sellMul = "number",
			bindOnPickup = "bool",
			dismantle = arr(AmountRange),
		})),
		sources = map(rec("DropSource", {
			chance = "number",
			min = "int",
			max = "int",
			["extra?"] = "number",
			cap = enum("RarityKey"),
			weights = map("number"),
		})),
		upgradeStatPerLevel = "number",
	})
)

S.file(
	"elements",
	rec("ElementsFile", {
		elements = arr(rec("Element", { id = enum("ElementId"), name = "name", color = "color", weapon = "bool" })),
		default = enum("ElementId"),
	})
)

S.file(
	"classes",
	rec("ClassesFile", {
		classes = arr(rec("ClassInfo", {
			id = enum("ClassId"),
			order = "int",
			name = "name",
			role = "name",
			desc = "name",
			mainStats = arr("string"),
			resource = "string",
			startStats = map("int"),
			weaponTypes = arr("string"),
			offhandTypes = arr("string"),
			basicAttack = rec("BasicAttack", { kind = "string", ranged = "bool", style = "string" }),
			color = "color",
			icon = "string",
			startingGear = arr("ref:items"),
		})),
	})
)

S.file(
	"stats",
	rec("StatsFile", {
		stats = arr(rec("StatInfo", {
			id = "string",
			name = "name",
			group = "string",
			format = "string",
			decimals = "int",
			["cap?"] = "number",
			order = "int",
		})),
		groups = arr(rec("StatGroupInfo", { id = "string", name = "name" })),
		primary = arr("string"),
		formula = "data",
	})
)

S.file(
	"progression",
	rec("ProgressionFile", {
		expToNext = arr(rec("LevelExp", { level = "int", exp = "int", total = "int" })),
		levelDiff = arr(rec("LevelDiff", { diff = "int", multiplier = "number" })),
		variantExp = map("number"),
		statPointsPerLevel = "int",
		skillPointsPerLevel = "int",
		skillPointsFromLevel = "int",
		maxLevel = "int",
	})
)

S.file(
	"mechanics",
	rec("MechanicsFile", {
		combat = "data",
		formula = "data",
		config = map("number"),
		zones = map(rec("ZoneInfo", { name = "name", rule = "name", color = "color" })),
		variants = map(rec("VariantInfo", {
			["name?"] = "name",
			levelAdd = "number",
			hpMul = "number",
			dmgMul = "number",
			scale = "number",
			aggroRange = "number",
			expMul = "number",
			goldMul = "number",
		})),
		["areaProfiles?"] = map(rec("AreaProfileInfo", {
			id = "string",
			icon = "string",
			color = "color",
			name = "name",
			desc = "name",
			sizeWeights = arr("number"),
			respawn = rec("Seconds", { min = "number", max = "number" }),
			hpMul = "number",
			atkMul = "number",
			expMul = "number",
			goldMul = "number",
			itemChanceMul = "number",
			topTierMul = "number",
			materialMul = "number",
		})),
		bossDailyRuns = "int",
	})
)

S.file(
	"titles",
	rec("TitlesFile", {
		titles = arr(rec("Title", {
			id = "string",
			name = "name",
			color = "color",
			req = rec("TitleReq", { kind = "string", value = "int" }),
		})),
	})
)

S.file(
	"blessings",
	rec("BlessingsFile", {
		blessings = arr(rec("Blessing", {
			id = "string",
			line = "string",
			rarity = enum("RarityKey"),
			name = "name",
			item = "ref:items",
			stats = map("number"),
		})),
		lines = arr("string"),
		duration = "int",
		elixirs = arr(rec("Elixir", { stat = "string", name = "name" })),
		elixirDuration = "int",
		elixirValue = "number",
	})
)

S.file(
	"cosmetics",
	rec("CosmeticsFile", {
		cosmetics = arr(rec("Cosmetic", {
			id = "string",
			kind = "string",
			name = "name",
			["desc?"] = "name",
			icon = "string",
			color = "color",
			["color2?"] = "color",
		})),
		kinds = arr(rec("CosmeticKind", { id = "string", ["name?"] = "name" })),
	})
)

S.file(
	"fish",
	rec("FishFile", {
		spots = arr(rec("FishSpot", {
			id = "string",
			chestChance = "number",
			fish = arr(
				rec("FishCatch", { id = "ref:items", weight = "number", chance = "number", rarity = enum("RarityKey") })
			),
		})),
		chest = rec("FishChest", { gold = "int", loot = arr(AmountRange) }),
	})
)

S.file(
	"gather",
	rec("GatherFile", {
		nodes = arr(rec("GatherNode", {
			id = "string",
			name = "name",
			category = "string",
			["tool?"] = "ref:items",
			level = "int",
			time = "number",
			respawn = "number",
			color = "color",
			shape = "string",
			["spot?"] = "string",
			loot = arr(AmountRange),
		})),
		placements = map(arr(Places.Placement)), -- S37: where nodes are on the region maps
	})
)

S.file(
	"recipes",
	rec("RecipesFile", {
		recipes = arr(rec("AlchemyRecipe", {
			id = "string",
			group = "string",
			level = "int",
			gold = "int",
			time = "number",
			result = Amount,
			ingredients = arr(Amount),
		})),
		groups = arr(rec("RecipeGroup", { id = "string", ["name?"] = "name" })),
		queueSlots = "int",
	})
)

-- Builders ---------------------------------------------------------------------------------------------------

function Basics.rarityKey(id: number): string
	return Rarities.get(id).key
end

function Basics.rarities(_ctx: any): any
	local list = {}
	for _, r in Rarities.list do
		table.insert(list, {
			id = r.id,
			key = r.key,
			name = Names.of(r.nameKey),
			short = Names.of(r.shortKey),
			color = r.hex,
			textColor = r.textHex,
			bonusMin = r.bonusMin,
			bonusMax = r.bonusMax,
			legendaryLines = r.legendaryLines,
			baseMul = r.baseMul,
			rangeMul = r.rangeMul,
			sellMul = r.sellMul,
			bindOnPickup = r.bindOnPickup,
			dismantle = Clean.clean(r.dismantle),
		})
	end
	local sources = {}
	for _, variant in Clean.keys(Rarities.itemDrops) do
		local drops = Rarities.itemDrops[variant]
		local weights = Rarities.dropWeights[variant] or {}
		local total = 0
		for _, w in weights do
			total += w
		end
		local shares = {}
		for rarity, w in weights do
			shares[Basics.rarityKey(rarity)] = w / total
		end
		sources[variant] = {
			chance = drops.chance,
			min = drops.min,
			max = drops.max,
			extra = drops.extra,
			cap = Basics.rarityKey(Rarities.cap[variant] or Rarities.COMMON),
			weights = shares,
		}
	end
	return { rarities = list, sources = sources, upgradeStatPerLevel = Rarities.upgradeStatPerLevel }
end

function Basics.elements(_ctx: any): any
	local list = {}
	for _, id in Clean.keys(Elements.COLORS) do
		table.insert(list, {
			id = id,
			name = Names.of(Elements.nameKey(id)),
			color = Elements.COLORS[id],
			weapon = Elements.isWeaponElement(id),
		})
	end
	return { elements = list, default = Elements.DEFAULT }
end

function Basics.classes(_ctx: any): any
	local list = {}
	for i, id in Classes.order do
		local c = Classes.get(id) :: Classes.ClassDef
		table.insert(list, {
			id = id,
			order = i,
			name = Names.of(c.nameKey),
			role = Names.of(c.roleKey),
			desc = Names.of(c.descKey),
			mainStats = Clean.clean(c.mainStats),
			resource = c.resource,
			startStats = Clean.clean(c.startStats),
			weaponTypes = Clean.clean(c.weaponTypes),
			offhandTypes = Clean.clean(c.offhandTypes),
			basicAttack = Clean.pick(c.basicAttack :: any, { "kind", "ranged", "style" }),
			color = c.color,
			icon = c.icon,
			startingGear = Clean.clean(Items.startingGear[id] or {}),
		})
	end
	return { classes = list }
end

function Basics.stats(_ctx: any): any
	local list = {}
	for _, def in Stats.list do
		table.insert(list, {
			id = def.id,
			name = Names.of(def.nameKey),
			group = def.group,
			format = def.format,
			decimals = def.decimals,
			cap = def.cap,
			order = def.order,
		})
	end
	local groups = {}
	for _, id in Stats.groups do
		table.insert(groups, { id = id, name = Names.of(`statGroup.{id}`) })
	end
	return {
		stats = list,
		groups = groups,
		primary = Clean.clean(Stats.primary),
		formula = Clean.clean(Stats.Formula),
	}
end

function Basics.progression(_ctx: any): any
	local levels = {}
	local total = 0
	for level = 1, Config.MaxLevel - 1 do
		local need = Exp.expToNext(level)
		total += need
		table.insert(levels, { level = level, exp = need, total = total })
	end
	local diffs = {}
	for diff = -10, 20 do
		local player = 50
		table.insert(diffs, { diff = diff, multiplier = Exp.levelDiffMultiplier(player, player + diff) })
	end
	return {
		expToNext = levels,
		levelDiff = diffs,
		variantExp = Clean.clean(Progression.variantMultiplier),
		statPointsPerLevel = Progression.statPointsPerLevel,
		skillPointsPerLevel = Progression.skillPointsPerLevel,
		skillPointsFromLevel = Progression.skillPointsFromLevel,
		maxLevel = Config.MaxLevel,
	}
end

-- Zone colours from src/client/UI/Theme.luau read as text (the client module does not load in Lune).
function Basics.zoneColors(themeText: string?, warnings: { string }): { [string]: string }
	local out = {}
	for zone, name in { green = "ZoneGreen", yellow = "ZoneYellow", red = "ZoneRed" } do
		local hex = themeText and string.match(themeText, name .. '%s*=%s*Color3%.fromHex%("(#%x%x%x%x%x%x)"%)')
		if hex then
			out[zone] = string.upper(hex)
		else
			table.insert(warnings, `Theme.luau: {name} not found, using {ZONE_COLORS_FALLBACK[zone]}`)
			out[zone] = ZONE_COLORS_FALLBACK[zone]
		end
	end
	return out
end

function Basics.mechanics(ctx: any): any
	local config = {}
	for _, key in Basics.CONFIG_KEYS do
		local value = (Config :: any)[key]
		assert(type(value) == "number", `Config.{key} is not a number`)
		config[key] = value
	end
	local colors = Basics.zoneColors(ctx.themeText, ctx.warnings)
	local zones = {}
	for _, zone in { "green", "yellow", "red" } do
		zones[zone] = { name = Names.of(`zone.{zone}`), rule = Names.of(`pvp.rules.{zone}`), color = colors[zone] }
	end
	local variants = {}
	for _, v in Clean.keys(Combat.variants) do
		local mods = (Combat.variants :: any)[v]
		variants[v] = {
			name = Names.opt(`variant.{v}`),
			levelAdd = mods.levelAdd,
			hpMul = mods.hpMul,
			dmgMul = mods.dmgMul,
			scale = mods.scale,
			aggroRange = mods.aggroRange,
			expMul = (Progression.variantMultiplier :: any)[v] or 1,
			goldMul = (Combat.goldVariantMultiplier :: any)[v] or 1,
		}
	end
	local profiles = nil
	if ctx.features.areaProfiles then
		local AreaProfiles = (require :: any)("../../src/shared/Data/AreaProfiles")
		profiles = {}
		for _, id in AreaProfiles.order do
			local p = AreaProfiles.get(id)
			profiles[id] = {
				id = id,
				icon = p.icon,
				color = p.color,
				name = Names.of(p.nameKey),
				desc = Names.of(p.descKey),
				sizeWeights = {
					p.sizeWeights[1] or 0,
					p.sizeWeights[2] or 0,
					p.sizeWeights[3] or 0,
					p.sizeWeights[4] or 0,
				},
				respawn = { min = p.respawn.min, max = p.respawn.max },
				hpMul = p.hpMul,
				atkMul = p.atkMul,
				expMul = p.expMul,
				goldMul = p.goldMul,
				itemChanceMul = p.itemChanceMul,
				topTierMul = p.topTierMul,
				materialMul = p.materialMul,
			}
		end
	end
	return {
		combat = Clean.clean(Combat),
		formula = Clean.clean(Stats.Formula),
		config = config,
		zones = zones,
		variants = variants,
		areaProfiles = profiles,
		bossDailyRuns = (Config :: any).Boss and (Config :: any).Boss.dailyRuns or 1,
	}
end

function Basics.titles(ctx: any): any
	local list = {}
	for _, t in Titles.list do
		if not ctx.hidden[t.id] then
			table.insert(list, { id = t.id, name = Names.of(t.nameKey), color = t.color, req = Clean.clean(t.req) })
		end
	end
	return { titles = list }
end

function Basics.blessings(ctx: any): any
	local list = {}
	for _, b in Blessings.list do
		if not ctx.hidden[b.id] then
			table.insert(list, {
				id = b.id,
				line = b.line,
				rarity = Basics.rarityKey(b.rarity),
				name = Names.of(b.nameKey),
				item = b.itemId,
				stats = Clean.clean(b.stats),
			})
		end
	end
	local elixirs = {}
	for _, stat in Blessings.ELIXIRS do
		table.insert(elixirs, { stat = stat, name = Names.of(`stat.{stat}`) })
	end
	return {
		blessings = list,
		lines = Clean.clean(Blessings.lines),
		duration = Blessings.DURATION,
		elixirs = elixirs,
		elixirDuration = Blessings.ELIXIR_DURATION,
		elixirValue = Blessings.ELIXIR_VALUE,
	}
end

function Basics.cosmetics(ctx: any): any
	local list = {}
	for _, c in Cosmetics.list do
		if not ctx.hidden[c.id] then
			-- Never the price (Robux / Dragon Currency).
			table.insert(list, {
				id = c.id,
				kind = c.kind,
				name = Names.of(c.nameKey),
				desc = Names.opt(`{c.nameKey}.desc`),
				icon = c.icon,
				color = c.color,
				color2 = c.color2,
			})
		end
	end
	local kinds = {}
	for _, kind in Cosmetics.kinds do
		table.insert(kinds, { id = kind, name = Names.opt(`wardrobe.kind.{kind}`) })
	end
	return { cosmetics = list, kinds = kinds }
end

function Basics.fish(_ctx: any): any
	local spots = {}
	for _, id in Clean.keys(Fish.spots) do
		local spot = Fish.spots[id]
		local total = 0
		for _, f in spot.fish do
			total += f.weight
		end
		local fish = {}
		for _, f in spot.fish do
			table.insert(fish, {
				id = f.id,
				weight = f.weight,
				chance = f.weight / total,
				rarity = Basics.rarityKey(f.rarity),
			})
		end
		table.insert(spots, { id = id, chestChance = spot.chestChance, fish = fish })
	end
	return { spots = spots, chest = { gold = Fish.CHEST_GOLD, loot = Clean.clean(Fish.CHEST_LOOT) } }
end

function Basics.gather(ctx: any): any
	local nodes = {}
	for _, id in Clean.keys(GatherNodes.kinds) do
		local n = GatherNodes.kinds[id]
		table.insert(nodes, {
			id = id,
			name = Names.of(n.nameKey),
			category = n.category,
			tool = n.tool,
			level = n.level,
			time = n.time,
			respawn = n.respawn,
			color = (n.look :: any).color,
			shape = (n.look :: any).shape,
			spot = n.spot,
			loot = Clean.clean(n.loot),
		})
	end
	return { nodes = nodes, placements = Places.gather(ctx.readText, ctx.warnings) }
end

function Basics.recipes(ctx: any): any
	local list = {}
	for _, r in Recipes.list do
		if not ctx.hidden[r.result.id] then
			table.insert(list, {
				id = r.id,
				group = r.group,
				level = r.level,
				gold = r.gold,
				time = r.time,
				result = Clean.clean(r.result),
				ingredients = Clean.clean(r.ingredients),
			})
		end
	end
	local groups = {}
	for _, g in Recipes.groups do
		table.insert(groups, { id = g, name = Names.opt(`alchemy.group.{g}`) })
	end
	return { recipes = list, groups = groups, queueSlots = Recipes.QUEUE_SLOTS }
end

-- Enums from the game data (types.ts unions and validation).
function Basics.registerEnums()
	local keys = {}
	for _, r in Rarities.list do
		table.insert(keys, r.key)
	end
	S.setEnum("RarityKey", keys)
	S.setEnum("ElementId", Clean.keys(Elements.COLORS))
	S.setEnum("ClassId", Classes.order)
end

return Basics
