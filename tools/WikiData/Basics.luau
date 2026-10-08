--!strict
-- Small wiki data files (S34): rarities, elements, classes, stats, progression, mechanics, titles, blessings,
-- cosmetics (no prices), fish, gathering, alchemy recipes. Every number comes from src/shared/Data or a Logic
-- function; names through Names (Util/Locale).

local Blessings = require("../../src/shared/Data/Blessings")
local Classes = require("../../src/shared/Data/Classes")
local Clean = require("./Clean")
local Combat = require("../../src/shared/Data/Combat")
local AreaAdvice = require("../../src/shared/Logic/AreaAdvice")
local Config = require("../../src/shared/Config")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local Elements = require("../../src/shared/Data/Elements")
local Damage = require("../../src/shared/Logic/Damage")
local Exp = require("../../src/shared/Logic/Exp")
local KeybindData = require("../../src/shared/Data/Keybinds")
local Keybinds = require("../../src/shared/Logic/Keybinds")
local LevelBand = require("../../src/shared/Logic/LevelBand")
local Maps = require("../../src/shared/Data/Maps")
local PvpRules = require("../../src/shared/Logic/PvpRules")
local Fish = require("../../src/shared/Data/Fish")
local Guild = require("../../src/shared/Logic/Guild")
local GuildSkills = require("../../src/shared/Data/GuildSkills")
local Auction = require("../../src/shared/Logic/Auction")
local Market = require("../../src/shared/Data/Market")
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
local World = require("./World")

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
	"TradeInviteSeconds",
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
		primaryNames = map("name"),
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
		-- S42: EXP of a monster per level and variant, the best hunting area of every level, level-gap rules
		monsterExp = arr(rec("MonsterExpRow", { level = "int", exp = map("number") })),
		bestArea = arr(rec("BestArea", { level = "int", map = "ref:maps", area = "ref:areas" })),
		levelDiffRules = rec("LevelDiffRules", {
			freeDiff = "number",
			penaltyPerLevel = "number",
			minMultiplier = "number",
			bonusPerLevel = "number",
			maxBonus = "number",
		}),
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
		-- S42
		keybinds = arr(rec("KeybindInfo", { id = "string", group = "string", key = "string", name = "name" })),
		levelBands = arr(rec("LevelBandInfo", { band = "string", min = "int", max = "int", color = "color" })),
		reduction = rec("ReductionTable", {
			levels = arr("int"),
			rows = arr(rec("ReductionRow", { defense = "int", values = arr("number") })),
		}),
		pvp = rec("PvpInfo", {
			rows = arr(rec("PvpCase", {
				zone = "string",
				relation = "string",
				attackerPvp = "bool",
				targetPvp = "bool",
				allowed = "bool",
				["reason?"] = "string",
				["reasonName?"] = "name",
			})),
			toggleMatters = map("bool"),
		}),
		-- S43
		guild = rec("GuildInfo", {
			skills = arr(rec("GuildSkillInfo", {
				id = "string",
				icon = "string",
				stat = "string",
				name = "name",
				costs = arr("int"),
				effects = arr("number"),
				desc = arr("name"),
			})),
			maxLevel = "int",
			rules = map("number"),
			memberLimits = arr("int"),
			ranks = arr(rec("GuildRankInfo", { id = "string", name = "name", can = map("bool") })),
			actions = arr("string"),
		}),
		market = rec("MarketInfo", {
			auction = rec("AuctionRules", {
				depositPct = "number",
				feePct = "number",
				durations = arr("int"),
				maxListings = "int",
			}),
			mail = rec("MailRules", { lifetimeDays = "int", maxParcels = "int", maxItemsPerParcel = "int" }),
			categories = arr(rec("AuctionCategory", { id = "string", name = "name" })),
			examples = arr(rec("AuctionExample", { gold = "int", deposit = "int", fee = "int", payout = "int" })),
		}),
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
			["parts?"] = arr("string"), -- S43: outfit accessories
			["flies?"] = "bool", -- S43: pets
		})),
		kinds = arr(rec("CosmeticKind", { id = "string", ["name?"] = "name" })),
		-- S43: wardrobe and shop texts of the game
		texts = rec("CosmeticTexts", { hint = "name", pack = "name", wardrobe = "name" }),
	})
)

S.file(
	"fish",
	rec("FishFile", {
		spots = arr(rec("FishSpot", {
			id = "string",
			chestChance = "number",
			fish = arr(rec("FishCatch", {
				id = "ref:items",
				weight = "number",
				chance = "number",
				rarity = enum("RarityKey"),
				zone = "number",
				speed = "number",
			})),
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
	-- S41: names of the primary stats (class pages: main and starting stats).
	local primaryNames = {}
	for _, id in Stats.primary do
		primaryNames[id] = Names.of(`stat.{id}`)
	end
	local groups = {}
	for _, id in Stats.groups do
		table.insert(groups, { id = id, name = Names.of(`statGroup.{id}`) })
	end
	return {
		stats = list,
		groups = groups,
		primary = Clean.clean(Stats.primary),
		primaryNames = primaryNames,
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
		monsterExp = Basics.monsterExp(),
		bestArea = Basics.bestArea(),
		levelDiffRules = {
			freeDiff = Progression.freeDiff,
			penaltyPerLevel = Progression.penaltyPerLevel,
			minMultiplier = Progression.minMultiplier,
			bonusPerLevel = Progression.bonusPerLevel,
			maxBonus = Progression.maxBonus,
		},
	}
end

Basics.MONSTER_EXP_VARIANTS = { "normal", "elite", "elite2", "boss" }

-- Exp.monsterExp on levels 1, 10, 20, ..., MaxLevel for every variant (S42).
function Basics.monsterExp(): { any }
	local out = {}
	local levels = { 1 }
	for level = 10, Config.MaxLevel, 10 do
		table.insert(levels, level)
	end
	for _, level in levels do
		local exp = {}
		for _, v in Basics.MONSTER_EXP_VARIANTS do
			exp[v] = Exp.monsterExp(level, v :: any)
		end
		table.insert(out, { level = level, exp = exp })
	end
	return out
end

-- Region maps sorted by their minimum level.
function Basics.regionMaps(): { any }
	local regions = {}
	for _, id in Clean.keys(Maps.byId) do
		local m = (Maps.byId :: any)[id]
		if World.mapKind(m) == "region" then
			table.insert(regions, m)
		end
	end
	table.sort(regions, function(a, b)
		return a.minLevel < b.minLevel or (a.minLevel == b.minLevel and a.id < b.id)
	end)
	return regions
end

-- Best region area for every level (S42): among the region maps whose range holds the level, AreaAdvice.best
-- of the map whose area is recommended and nearest by its range middle (the later map on a tie).
function Basics.bestArea(): { any }
	local regions = Basics.regionMaps()
	local out = {}
	for level = 1, Config.MaxLevel do
		local best, bestMap, bestScore = nil, nil, math.huge
		for _, m in regions do
			if level >= m.minLevel and level <= m.maxLevel then
				local area = AreaAdvice.best(level, m.id)
				if area then
					local score = math.abs((area.lv[1] + area.lv[2]) / 2 - level)
					if not AreaAdvice.isRecommended(area, level) then
						score += 1000
					end
					if score <= bestScore then
						best, bestMap, bestScore = area, m.id, score
					end
				end
			end
		end
		if not best and #regions > 0 then
			local nearest = if level < regions[1].minLevel then regions[1] else regions[#regions]
			best, bestMap = AreaAdvice.best(level, nearest.id), nearest.id
		end
		if best then
			table.insert(out, { level = level, map = bestMap, area = best.id })
		end
	end
	return out
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
		keybinds = Basics.keybinds(),
		levelBands = Basics.levelBands(),
		reduction = Basics.reduction(),
		pvp = Basics.pvp(),
		guild = Basics.guild(),
		market = Basics.market(),
	}
end

Basics.GUILD_ACTIONS = { "deposit", "invite", "kick", "motd", "upgrade", "promote", "settings", "transfer", "disband" }

-- Guild skills with their effect and cost on every level, rules, member limits and rank permissions (S43).
function Basics.guild(): any
	local skills = {}
	for _, def in GuildSkills.list do
		local effects, desc = {}, {}
		for n = 1, GuildSkills.MAX_LEVEL do
			local value = Guild.skillEffect(def.id, n)
			table.insert(effects, value)
			table.insert(desc, Names.of(def.descKey, { value = value }))
		end
		table.insert(skills, {
			id = def.id,
			icon = def.icon,
			stat = def.stat,
			name = Names.of(def.nameKey),
			costs = table.clone(def.costs),
			effects = effects,
			desc = desc,
		})
	end
	local rules = {}
	for key, value in GuildSkills.Rules :: any do
		if key ~= "maxDeposit" then
			rules[key] = value
		end
	end
	local limits = {}
	for n = 0, GuildSkills.MAX_LEVEL do
		table.insert(limits, Guild.memberLimit({ expansion = n }))
	end
	local ranks = {}
	for _, rank in Guild.RANKS do
		local can = {}
		for _, action in Basics.GUILD_ACTIONS do
			can[action] = Guild.can(rank, action :: any)
		end
		table.insert(ranks, { id = rank, name = Names.of(`guild.rank.{rank}`), can = can })
	end
	return {
		skills = skills,
		maxLevel = GuildSkills.MAX_LEVEL,
		rules = rules,
		memberLimits = limits,
		ranks = ranks,
		actions = table.clone(Basics.GUILD_ACTIONS),
	}
end

Basics.AUCTION_EXAMPLES = { 1000, 100000 }

-- Auction house and mail rules, categories and two payout examples (S43).
function Basics.market(): any
	local categories = {}
	for _, c in Market.categories do
		table.insert(categories, { id = c.id, name = Names.of(c.nameKey) })
	end
	local examples = {}
	for _, price in Basics.AUCTION_EXAMPLES do
		local deposit = Auction.deposit(price)
		table.insert(examples, {
			gold = price,
			deposit = deposit,
			fee = Auction.fee(price),
			payout = Auction.payout(price, deposit),
		})
	end
	return {
		auction = {
			depositPct = Market.Auction.depositPct,
			feePct = Market.Auction.feePct,
			durations = table.clone(Market.Auction.durations),
			maxListings = Market.Auction.maxListings,
		},
		mail = {
			lifetimeDays = Market.Mail.lifetimeDays,
			maxParcels = Market.Mail.maxParcels,
			maxItemsPerParcel = Market.Mail.maxItemsPerParcel,
		},
		categories = categories,
		examples = examples,
	}
end

local function stripHint(text: string): string
	return (string.gsub(text, "%s*%b()$", ""))
end

-- Default keys of the rebindable actions in data order (S42); names without the " (C)" hint of the HUD texts.
function Basics.keybinds(): { any }
	local out = {}
	for _, a in KeybindData.actions do
		local n = Names.of(a.labelKey)
		table.insert(out, {
			id = a.id,
			group = a.group,
			key = Keybinds.label(a.default),
			name = { pl = stripHint(n.pl), en = stripHint(n.en) },
		})
	end
	return out
end

Basics.BAND_RANGE = { -15, 10 }

-- LevelBand.of(L + d, L) for d in BAND_RANGE gathered into ranges (the ends of the scan are open).
function Basics.levelBands(): { any }
	local out = {}
	local player = 50
	for d = Basics.BAND_RANGE[1], Basics.BAND_RANGE[2] do
		local band = LevelBand.of(player + d, player)
		local last = out[#out]
		if last and last.band == band then
			last.max = d
		else
			table.insert(out, { band = band, min = d, max = d, color = (LevelBand.COLORS :: any)[band] })
		end
	end
	return out
end

Basics.REDUCTION_DEFENSE = { 50, 100, 200, 400, 800, 1600 }
Basics.REDUCTION_LEVELS = { 10, 25, 50, 75, 100 }

-- Damage.reduction for a grid of defence x attacker level (S42), rounded to 0.01 %.
function Basics.reduction(): any
	local rows = {}
	for _, def in Basics.REDUCTION_DEFENSE do
		local values = {}
		for _, level in Basics.REDUCTION_LEVELS do
			table.insert(values, math.floor(Damage.reduction(def, level) * 10000 + 0.5) / 10000)
		end
		table.insert(rows, { defense = def, values = values })
	end
	return { levels = table.clone(Basics.REDUCTION_LEVELS), rows = rows }
end

Basics.PVP_RELATIONS = { "stranger", "party", "guild", "guildOpen" }
Basics.ZONES = { "green", "yellow", "red" }

-- PvpRules.canAttack for every zone x relation x own toggle x target toggle (S42).
function Basics.pvp(): any
	local rows = {}
	for _, zone in Basics.ZONES do
		for _, relation in Basics.PVP_RELATIONS do
			for _, mine in { true, false } do
				for _, theirs in { true, false } do
					local ok, reason = PvpRules.canAttack({ pvpEnabled = mine }, { pvpEnabled = theirs }, {
						zone = zone :: any,
						sameParty = relation == "party",
						sameGuild = relation == "guild" or relation == "guildOpen",
						guildProtection = relation ~= "guildOpen",
					})
					table.insert(rows, {
						zone = zone,
						relation = relation,
						attackerPvp = mine,
						targetPvp = theirs,
						allowed = ok,
						reason = if reason then (string.gsub(reason, "^pvp%.deny%.", "")) else nil,
						reasonName = if reason then Names.of(reason) else nil,
					})
				end
			end
		end
	end
	local matters = {}
	for _, zone in Basics.ZONES do
		matters[zone] = PvpRules.toggleMatters(zone :: any)
	end
	return { rows = rows, toggleMatters = matters }
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
				parts = if c.parts then Clean.clean(c.parts) else nil,
				flies = if c.kind == "pet" then c.flies == true else nil,
			})
		end
	end
	local kinds = {}
	for _, kind in Cosmetics.kinds do
		table.insert(kinds, { id = kind, name = Names.opt(`wardrobe.kind.{kind}`) })
	end
	return {
		cosmetics = list,
		kinds = kinds,
		texts = {
			hint = Names.of("wardrobe.hint"),
			pack = Names.of("premium.pack.desc"),
			wardrobe = Names.of("premium.wardrobe.desc"),
		},
	}
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
				zone = f.zone,
				speed = f.speed,
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
