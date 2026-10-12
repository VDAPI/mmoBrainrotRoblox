--!strict
-- Item tooltip content (S31, DESIGN §5, §23) as a pure list of lines, so every category can be tested in Lune.
-- `UI/Components/ItemTooltip` only draws the lines. Every item gets a header (name in the rarity colour,
-- "Rarity · Category"), its statistics or effect, requirements, the comparison with the equipped item and
-- the value line ("Value: X gold") with the context price.
--
-- ctx (every field optional):
--   lang: string           -- "pl" | "en" (default: Locale's current language)
--   level: number          -- character level (requirements turn red when higher; nil = treated as met)
--   class: string          -- character class id (class requirement)
--   equipped: ItemInstance -- the equipped item to compare with (caller picks the same slot group)
--   shop: Shops.ShopDef    -- shop the item is offered in
--   shopEntry: Shops.Entry -- the offered entry: adds "Price: X gold" (ShopPrice.unit, the same as the row)
--   potionDiscount: number -- guild potion discount (derived stat), for the shop price
--   merchantOpen: boolean  -- a merchant window is open: backpack items add "Sells for: X gold"
--   hints: boolean         -- false hides the "double click: equip/use" hint (default: shown outside shops)
--   pathId: string         -- S68: character.path.main (ItemScore weights of the main path)
--   nodes: {[id]: number}  -- S68: character.path.nodes (owned nodes are marked in trait details)
--   mainHand: ItemInstance -- S68: equipped weapon (Full Draw details; an off-hand against a two-hander)
--   offhand: ItemInstance  -- S68: equipped off-hand (a two-handed candidate also replaces it)
--   input: "mouse"|"touch" -- S68: picks the details hint; nil = no hint (tests, admin dump)
--   detailsKey: string     -- S68: label of the details key on PC (Keybinds.label("item_details"))
--
-- Line fields: `text` (may hold rich text), `role` (what the line is, for tests and the admin dump), `tone`
-- (colour role), `hex` (explicit colour, overrides tone), `size`, `font`; bonus rows have `kind = "bonus"`,
-- `quality` 0..1, `tier` (Data/Bonuses) and `legendary` / `mythic` from it. S62: weapons and off-hands get a "Trait"
-- section (name + line, Data/ItemTraits colour) after the base stats, only for live traits.
-- S68 (STATY 11): equipment goes name, damage / defence, Trait, regular lines, legendary, mythic, description,
-- requirements, comparison (% of the damage and survival axes from Logic/ItemScore, then the stat list); every bonus
-- and trait row carries a `detail` reference that `TooltipModel.details` turns into the details panel.

local Blessings = require("../Data/Blessings")
local Bonuses = require("../Data/Bonuses")
local Classes = require("../Data/Classes")
local Combat = require("../Data/Combat")
local Config = require("../Config")
local Crafting = require("../Data/Crafting")
local Elements = require("../Data/Elements")
local Format = require("../Util/Format")
local GatherNodes = require("../Data/GatherNodes")
local ItemName = require("./ItemName")
local BuffCategories = require("../Data/BuffCategories")
local ItemRoll = require("./ItemRoll")
local ItemScore = require("./ItemScore")
local ItemTraits = require("../Data/ItemTraits")
local ItemValue = require("./ItemValue")
local ItemWeights = require("../Data/ItemWeights")
local Items = require("../Data/Items")
local Locale = require("../Util/Locale")
local Luck = require("../Data/Luck")
local PathData = require("../Data/Paths")
local Quests = require("../Data/Quests")
local Rarities = require("../Data/Rarities")
local Recipes = require("../Data/Recipes")
local ShopPrice = require("./ShopPrice")
local Shops = require("../Data/Shops")
local Stats = require("../Data/Stats")
local Traits = require("./Traits")
local Types = require("../Types")
local Upgrade = require("./Upgrade")

type ItemInstance = Types.ItemInstance
type ItemDef = Items.ItemDef

export type Tone = "dark" | "muted" | "good" | "bad" | "rarity" | "bonus" | "legendary" | "trait"
export type Tier = "regular" | "legendary" | "mythic"

-- S68: what a row's details panel describes (a bonus line of this item, or the item's trait).
export type DetailRef = { kind: "bonus", id: string, v: number, quality: number? } | { kind: "trait", id: string }
export type DetailRow = { role: string, text: string, tone: Tone? }
export type Details = { title: string, tier: Tier | "trait", rows: { DetailRow } }
export type TraitNode = { path: string, node: string, nodeId: string, owned: boolean }

export type Line = {
	kind: "text" | "bonus",
	role: string,
	text: string,
	tone: Tone,
	hex: string?,
	size: ("large" | "body" | "small")?,
	font: ("heading" | "bold" | "medium")?,
	quality: number?,
	legendary: boolean?,
	mythic: boolean?, -- line from the mythic pool (FIX 2026-10-09)
	tier: Tier?, -- Bonuses tier of a bonus row (S62)
	detail: DetailRef?, -- S68: rows that open a details panel
}

export type Ctx = {
	lang: string?,
	level: number?,
	class: string?,
	equipped: ItemInstance?,
	shop: Shops.ShopDef?,
	shopEntry: Shops.Entry?,
	potionDiscount: number?,
	merchantOpen: boolean?,
	hints: boolean?,
	pathId: string?,
	nodes: { [string]: number }?,
	mainHand: ItemInstance?,
	offhand: ItemInstance?,
	input: ("mouse" | "touch")?,
	detailsKey: string?,
}

export type Model = { lines: { Line } }

local TooltipModel = {}

-- S68 (STATY 11): bonus rows sort by tier, then by their index on the item.
TooltipModel.TIER_ORDER = table.freeze({ regular = 1, legendary = 2, mythic = 3 })

-- Formatting ----------------------------------------------------------------------------------------------

local ALIASES: { [string]: string } = { hp = "maxHp", mana = "maxMana", energy = "maxEnergy" }

-- Decimal number in the language's style ("1,20" in Polish, "1.20" in English).
local function decimal(value: number, places: number, lang: string): string
	local text = string.format(`%.{places}f`, value)
	return if lang == "pl" then (string.gsub(text, "%.", ",")) else text
end
TooltipModel.decimal = decimal

local function statName(lang: string, key: string): string
	local id = ItemRoll.baseKey(key)
	return Locale.T(`stat.{ALIASES[id] or id}`, nil, lang)
end

local function formatStat(key: string, value: number, lang: string): string
	local id, isPct = ItemRoll.baseKey(key)
	if isPct then
		return decimal(value, if value % 1 == 0 then 0 else 1, lang) .. "%"
	end
	local def = Stats.get(ALIASES[id] or id)
	local places = if def then def.decimals else (if value % 1 == 0 then 0 else 1)
	local text = if places == 0 then Format.number(value) else decimal(value, places, lang)
	return if def and def.format == "pct" then text .. "%" else text
end

local function bonusText(lang: string, id: string, value: number): string
	local def = Bonuses.get(id)
	local places = if def then def.decimals else 0
	local v = if places == 0 then tostring(math.floor(value + 0.5)) else decimal(value, places, lang)
	return Locale.T(`bonus.{id}`, { v = v }, lang)
end

-- Trait numbers: whole when within 0.05 of an integer, else one decimal (language style).
local function traitNumber(value: number, lang: string): string
	local whole = math.floor(value + 0.5)
	if math.abs(value - whole) < 0.05 then
		return tostring(whole)
	end
	return decimal(value, 1, lang)
end

-- Placeholders of a trait line: {v} = grown value (value x power), every params field unchanged, language style.
function TooltipModel.traitArgs(traitId: string, power: number, lang: string): { [string]: string }
	local def = ItemTraits.get(traitId)
	local args: { [string]: string } = {}
	if not def then
		return args
	end
	local params: { [string]: number } = def.params or {}
	for key, value in params do
		args[key] = traitNumber(value, lang)
	end
	local grown = def.value * power
	-- S65: a grown chance shows at most the on-hit chance cap (Elemental Spark, Harrying, Concussion).
	args.v = traitNumber(if def.chanceCap then math.min(grown, Combat.onHitChanceCap) else grown, lang)
	-- S63: fixed numbers of an on-hit trait (Data/ItemTraits onHit), styled like {v}.
	local onHit = def.onHit
	if onHit then
		args.s = traitNumber(onHit.duration, lang)
		if onHit.chance then
			args.chance = traitNumber(onHit.chance, lang)
		end
		if onHit.slow then
			args.slow = traitNumber(onHit.slow, lang)
		end
		if onHit.effect == "armorBreak" then
			args.max = traitNumber(Traits.armorBreakCap(grown, onHit.maxStacks or 1), lang)
			args.pvpStacks = traitNumber(Combat.pvp.armorBreakStacks, lang)
		end
		-- S68: the rest of the on-hit numbers for the details texts (trait.<id>.info / .pvp).
		if onHit.maxStacks then
			args.stacks = traitNumber(onHit.maxStacks, lang)
		end
		if onHit.attackSlow then
			args.attackSlow = traitNumber(onHit.attackSlow, lang)
		end
		if onHit.healCut then
			args.healCut = traitNumber(onHit.healCut, lang)
		end
		if onHit.gap then
			args.gap = traitNumber(onHit.gap, lang)
		end
	end
	-- S68: fixed hooks (Frostbite of ice weapons), the grown value against players and the PvP control multiplier.
	local fixedHooks: { [string]: number } = def.fixedHooks or {}
	for key, value in fixedHooks do
		if args[key] == nil then
			args[key] = traitNumber(value, lang)
		end
	end
	args.pvpV = traitNumber(grown * def.pvp, lang)
	args.cc = traitNumber(Config.PvpCcMultiplier, lang)
	return args
end

function TooltipModel.traitLine(traitId: string, power: number, lang: string): string
	local def = ItemTraits.get(traitId)
	if not def then
		return ""
	end
	return Locale.T(def.lineKey, TooltipModel.traitArgs(traitId, power, lang), lang)
end

local function gold(n: number): string
	return Format.number(n)
end

-- Category ------------------------------------------------------------------------------------------------

-- Locale key of the item's category ("itemCat.<id>"): weapon kind, slot or consumable kind.
function TooltipModel.categoryKey(def: ItemDef): string
	if def.category == "equipment" then
		if def.slot == "weapon" then
			local weapon = def.weapon
			if weapon and weapon.ranged then
				return "itemCat.weaponRanged"
			elseif weapon and weapon.twoHanded then
				return "itemCat.weapon2h"
			end
			return "itemCat.weapon1h"
		end
		return `itemCat.{def.slot or "equipment"}`
	elseif def.category == "consumable" then
		local kind = if def.use then def.use.kind else "potion"
		if kind == "blessing" or kind == "elixir" then
			return `itemCat.{kind}`
		end
		return "itemCat.potion"
	end
	return `itemCat.{def.category}`
end

-- Weapon damage per second: the higher of physical / magic damage times attacks per second.
function TooltipModel.dps(weapon: { dmg: number, mdmg: number, speed: number }): number
	return math.max(weapon.dmg, weapon.mdmg) * weapon.speed
end

-- Material usage (reverse index computed from the data) -----------------------------------------------------

type Usage = {
	upgrade: { from: number, to: number, rarities: { number }? }?,
	alchemy: { string }, -- result item ids (unique, data order)
	crafting: { from: number, to: number }?,
	quests: { string }, -- main quest ids gathering it
}

local usageIndex: { [string]: Usage }? = nil

local function usageOf(index: { [string]: Usage }, id: string): Usage
	local usage = index[id]
	if not usage then
		usage = { alchemy = {}, quests = {} }
		index[id] = usage
	end
	return usage
end

local function buildUsage(): { [string]: Usage }
	local index: { [string]: Usage } = {}
	-- Upgrades: every target level for every rarity.
	local needs: { [string]: { levels: { [number]: boolean }, rarities: { [number]: boolean } } } = {}
	for _, rarity in Rarities.list do
		local probe: ItemInstance =
			{ uid = "", id = "", rarity = rarity.id, ilvl = 1, bonuses = {}, up = 0, bound = false, n = 1 }
		for level = 1, Upgrade.MAX do
			for _, material in Upgrade.cost(probe, level).materials do
				local need = needs[material.id] or { levels = {}, rarities = {} }
				needs[material.id] = need
				need.levels[level] = true
				need.rarities[rarity.id] = true
			end
		end
	end
	for id, need in needs do
		local from, to = math.huge, 0
		for level in need.levels do
			from = math.min(from, level)
			to = math.max(to, level)
		end
		local rarities: { number } = {}
		for _, rarity in Rarities.list do
			if need.rarities[rarity.id] then
				table.insert(rarities, rarity.id)
			end
		end
		usageOf(index, id).upgrade =
			{ from = from, to = to, rarities = if #rarities < #Rarities.list then rarities else nil }
	end
	-- Alchemy: ingredient -> results.
	for _, recipe in Recipes.list do
		for _, ingredient in recipe.ingredients do
			local list = usageOf(index, ingredient.id).alchemy
			if not table.find(list, recipe.result.id) then
				table.insert(list, recipe.result.id)
			end
		end
	end
	-- Blacksmith crafting: material -> tier range.
	for _, recipe in Crafting.list do
		for _, material in recipe.materials do
			local usage = usageOf(index, material.id)
			local range = usage.crafting
			usage.crafting = {
				from = math.min(if range then range.from else recipe.level, recipe.level),
				to = math.max(if range then range.to else recipe.level, recipe.level),
			}
		end
	end
	-- Main quests that gather it from a node.
	for _, quest in Quests.Main.list do
		for _, objective in (quest :: any).objectives do
			local node = if objective.type == "gather" and objective.node then GatherNodes.get(objective.node) else nil
			if node then
				for _, loot in node.loot do
					if loot.chance >= 1 then
						local list = usageOf(index, loot.id).quests
						if not table.find(list, quest.id) then
							table.insert(list, quest.id)
						end
					end
				end
			end
		end
	end
	return index
end

function TooltipModel.usage(itemId: string): Usage?
	if usageIndex == nil then
		usageIndex = buildUsage()
	end
	return (usageIndex :: { [string]: Usage })[itemId]
end

local MAX_NAMES = 4

local function nameList(lang: string, all: { string }): string
	-- Blessings of one line share a name across rarities: list each name once.
	local names: { string } = {}
	for _, name in all do
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end
	if #names <= MAX_NAMES + 1 then
		return table.concat(names, ", ")
	end
	local shown = table.move(names, 1, MAX_NAMES, 1, {})
	return Locale.T("tooltip.use.andMore", { names = table.concat(shown, ", "), n = #names - MAX_NAMES }, lang)
end

-- Builder ---------------------------------------------------------------------------------------------------

type Builder = {
	lines: { Line },
	add: (role: string, text: string, tone: Tone?, extra: { [string]: any }?) -> (),
}

local function builder(): Builder
	local lines: { Line } = {}
	return {
		lines = lines,
		add = function(role: string, text: string, tone: Tone?, extra: { [string]: any }?)
			local entry: any = { kind = "text", role = role, text = text, tone = tone or "dark" }
			if extra then
				for k, v in extra do
					entry[k] = v
				end
			end
			table.insert(lines, entry :: Line)
		end,
	}
end

-- Numbers to compare between two items: weapon damage + flat totals.
local function comparable(item: ItemInstance): { [string]: number }
	local stats = ItemRoll.itemStats(item)
	local values: { [string]: number } = {}
	if stats.weapon then
		values.weaponDmg = stats.weapon.dmg
		values.weaponMdmg = stats.weapon.mdmg
	end
	for stat, v in stats.flat do
		local key = ALIASES[stat] or stat
		values[key] = (values[key] or 0) + v
	end
	for stat, v in stats.pct do
		local key = `{ALIASES[stat] or stat}Pct`
		values[key] = (values[key] or 0) + v
	end
	return values
end

-- Equipment header block: item level, element, then weapon damage / speed / DPS or the base stats.
local function equipmentStats(b: Builder, item: ItemInstance, stats: ItemRoll.ItemStats, lang: string)
	local element = ItemRoll.elementOf(item)
	b.add("ilvl", Locale.T("tooltip.ilvl", { ilvl = item.ilvl }, lang), "muted")
	if element then
		b.add(
			"element",
			Locale.T("tooltip.element", { element = Locale.T(`element.{element}`, nil, lang) }, lang),
			"dark",
			{ hex = Elements.COLORS[element] or "#FFFFFF" }
		)
	end
	local w = stats.weapon
	if w then
		if w.dmg > 0 then
			b.add("stat", Locale.T("tooltip.damage", { dmg = w.dmg }, lang), "dark", { size = "body", font = "bold" })
		end
		if w.mdmg > 0 then
			b.add(
				"stat",
				Locale.T("tooltip.magicDamage", { mdmg = w.mdmg }, lang),
				"dark",
				{ size = "body", font = "bold" }
			)
		end
		local tags = { Locale.T("tooltip.speed", { speed = decimal(w.speed, 2, lang) }, lang) }
		if w.twoHanded then
			table.insert(tags, Locale.T("tooltip.twoHanded", nil, lang))
		end
		if w.ranged then
			table.insert(tags, Locale.T("tooltip.ranged", nil, lang))
		end
		b.add("speed", table.concat(tags, " · "), "muted")
		b.add("dps", Locale.T("tooltip.dps", { dps = decimal(TooltipModel.dps(w), 1, lang) }, lang), "dark")
	end
	local keys = {}
	for stat in stats.base do
		table.insert(keys, stat)
	end
	table.sort(keys)
	for _, stat in keys do
		b.add("stat", `{statName(lang, stat)}: <b>{formatStat(stat, stats.base[stat], lang)}</b>`)
	end
end

-- S62 (STATY 11): the trait section, after damage / defence and before the lines.
local function traitLines(b: Builder, stats: ItemRoll.ItemStats, lang: string)
	if not stats.trait then
		return
	end
	local t = stats.trait :: ItemRoll.TraitRoll
	local detail: DetailRef = { kind = "trait", id = t.id }
	b.add(
		"traitName",
		`{ItemTraits.ICON} {Locale.T("tooltip.trait", { name = Locale.T(t.def.nameKey, nil, lang) }, lang)}`,
		"trait",
		{ hex = ItemTraits.COLOR, font = "bold", detail = detail }
	)
	b.add("trait", TooltipModel.traitLine(t.id, t.power, lang), "trait", { hex = ItemTraits.COLOR, detail = detail })
end

local function tierOf(id: string): Tier
	local def = Bonuses.get(id)
	return if def then def.tier else "regular"
end

-- Bonus rows: regular, then legendary, then mythic (S68), each tier in the item's order; the style comes from the
-- line's tier, never from its id or hook (S62, STATY 2C).
local function bonusLines(b: Builder, stats: ItemRoll.ItemStats, lang: string)
	local order: { number } = {}
	for index in stats.bonuses do
		table.insert(order, index)
	end
	table.sort(order, function(x: number, y: number): boolean
		local tx = TooltipModel.TIER_ORDER[tierOf(stats.bonuses[x].id)]
		local ty = TooltipModel.TIER_ORDER[tierOf(stats.bonuses[y].id)]
		if tx ~= ty then
			return tx < ty
		end
		return x < y
	end)
	for _, index in order do
		local bonus = stats.bonuses[index]
		local tier: Tier = tierOf(bonus.id)
		local entry: Line = {
			kind = "bonus",
			role = "bonus",
			text = bonusText(lang, bonus.id, bonus.v),
			tone = "bonus",
			quality = bonus.quality,
			legendary = tier == "legendary",
			mythic = tier == "mythic",
			tier = tier,
			detail = { kind = "bonus", id = bonus.id, v = bonus.v, quality = bonus.quality } :: DetailRef,
		}
		table.insert(b.lines, entry)
	end
end

local function blessingLines(b: Builder, def: ItemDef, lang: string)
	local blessing = def.use and def.use.target and Blessings.get(def.use.target)
	if not blessing then
		return
	end
	local ids = {}
	for stat in blessing.stats do
		table.insert(ids, stat)
	end
	table.sort(ids)
	for _, stat in ids do
		b.add("effect", `{statName(lang, stat)}: <b>+{formatStat(stat, blessing.stats[stat], lang)}</b>`)
	end
	b.add("duration", Locale.T("tooltip.blessingDuration", { minutes = Blessings.DURATION // 60 }, lang), "muted")
end

local function elixirLines(b: Builder, def: ItemDef, lang: string)
	local stat = def.use and def.use.target
	if not stat then
		return
	end
	b.add(
		"effect",
		Locale.T("tooltip.elixir", { stat = statName(lang, stat), value = Blessings.ELIXIR_VALUE }, lang),
		"dark",
		{ font = "bold" }
	)
	b.add(
		"duration",
		Locale.T("tooltip.blessingDuration", { minutes = Blessings.ELIXIR_DURATION // 60 }, lang),
		"muted"
	)
end

-- Stones and scrolls: what they do (regional dungeon stones use their own description).
local function useEffectLines(b: Builder, def: ItemDef, lang: string): boolean
	local use = def.use
	local target = use and use.target
	if not use or not target then
		return false
	end
	if use.kind == "teleport" and string.sub(target, 1, 8) == "dungeon:" and def.descKey then
		b.add("effect", Locale.T(def.descKey, nil, lang))
		return true
	end
	local key = if use.kind == "teleport" then `tooltip.effect.teleport.{target}` else `tooltip.effect.{target}`
	if not Locale.has(key, lang) then
		return false
	end
	b.add("effect", Locale.T(key, nil, lang))
	return true
end

-- Tools: which gathering they allow (from GatherNodes.tool).
local function toolLines(b: Builder, def: ItemDef, lang: string): boolean
	local categories: { string } = {}
	for _, node in GatherNodes.list do
		if node.tool == def.id and not table.find(categories, node.category) then
			table.insert(categories, node.category)
		end
	end
	table.sort(categories)
	for _, category in categories do
		b.add("effect", Locale.T(`tooltip.effect.tool.{category}`, nil, lang))
	end
	return #categories > 0
end

local function materialLines(b: Builder, def: ItemDef, lang: string)
	b.add("usedFor", Locale.T("tooltip.usedFor", nil, lang), "muted")
	local usage = TooltipModel.usage(def.id)
	local any = false
	if usage then
		local upgrade = usage.upgrade
		if upgrade then
			any = true
			local args: { [string]: any } = { from = upgrade.from, to = upgrade.to }
			if upgrade.rarities then
				local names = {}
				for _, id in upgrade.rarities do
					table.insert(names, Locale.T(Rarities.get(id).nameKey, nil, lang))
				end
				args.rarities = table.concat(names, ", ")
				b.add("use", Locale.T("tooltip.use.upgradeOnly", args, lang))
			else
				b.add("use", Locale.T("tooltip.use.upgrade", args, lang))
			end
		end
		if #usage.alchemy > 0 then
			any = true
			local names = {}
			for _, id in usage.alchemy do
				table.insert(names, ItemName.get(lang, id))
			end
			b.add("use", Locale.T("tooltip.use.alchemy", { names = nameList(lang, names) }, lang))
		end
		if usage.crafting then
			any = true
			b.add("use", Locale.T("tooltip.use.crafting", { from = usage.crafting.from, to = usage.crafting.to }, lang))
		end
		if #usage.quests > 0 then
			any = true
			local names = {}
			for _, id in usage.quests do
				table.insert(names, Locale.T(`quest.{id}.title`, nil, lang))
			end
			b.add("use", Locale.T("tooltip.use.quest", { names = nameList(lang, names) }, lang))
		end
	end
	if not any then
		b.add("use", Locale.T("tooltip.use.sell", nil, lang))
	end
	if def.tier then
		b.add("materialLevel", Locale.T("tooltip.materialLevel", { level = def.tier }, lang), "muted")
	end
end

local function compareLines(b: Builder, item: ItemInstance, equipped: ItemInstance, lang: string, titled: boolean)
	local mine, theirs = comparable(item), comparable(equipped)
	local keys: { [string]: boolean } = {}
	for k in mine do
		keys[k] = true
	end
	for k in theirs do
		keys[k] = true
	end
	local lines = {}
	for k in keys do
		local diff = (mine[k] or 0) - (theirs[k] or 0)
		if math.abs(diff) >= 0.05 then
			local label = if k == "weaponDmg"
				then Locale.T("tooltip.damage", { dmg = "" }, lang)
				elseif k == "weaponMdmg" then Locale.T("tooltip.magicDamage", { mdmg = "" }, lang)
				else statName(lang, k)
			local arrow = if diff > 0 then "↑" else "↓"
			local color = if diff > 0 then "#2E8B3E" else "#B8423A"
			local sign = if diff > 0 then "+" else "−"
			table.insert(
				lines,
				`<font color="{color}">{arrow} {sign}{formatStat(k, math.abs(diff), lang)} {label}</font>`
			)
		end
	end
	if #lines > 0 then
		table.sort(lines)
		if not titled then
			b.add("compareTitle", Locale.T("tooltip.compare", nil, lang), "muted")
		end
		b.add("compare", table.concat(lines, "\n"))
	end
end

local function isTwoHanded(item: ItemInstance): boolean
	local weapon = ItemRoll.itemStats(item).weapon
	return weapon ~= nil and weapon.twoHanded
end

-- "+4,2%" / "−1,5%" in the language's style.
local function signedPct(value: number, lang: string): string
	local sign = if value > 0 then "+" elseif value < 0 then "−" else ""
	return `{sign}{decimal(math.abs(value), 1, lang)}%`
end

local PCT_AXES = { "dmg", "surv", "support" }

-- S68 (STATY 11): the comparison block: % change of the damage / survival (and support) axes from ItemScore, then
-- the stat list. A two-handed candidate also replaces the off-hand; an off-hand cannot go next to a two-hander.
local function comparison(b: Builder, item: ItemInstance, d: ItemDef, c: Ctx, lang: string)
	local equipped = c.equipped
	if equipped and equipped.uid == item.uid then
		return
	end
	if d.slot == "offhand" and c.mainHand and isTwoHanded(c.mainHand) then
		b.add("compareNote", Locale.T("equip.error.twoHanded", nil, lang), "bad")
		return
	end
	local replaced: { ItemInstance } = {}
	if equipped then
		table.insert(replaced, equipped)
	end
	-- An empty weapon slot is no comparison (percentDelta nil), even with an off-hand worn.
	local offhand = if equipped and d.slot == "weapon" and isTwoHanded(item) then c.offhand else nil
	if offhand and offhand.uid ~= item.uid then
		table.insert(replaced, offhand)
	else
		offhand = nil
	end
	local delta = if c.class
		then ItemScore.percentDelta(item, replaced, { classId = c.class, level = c.level, pathId = c.pathId })
		else nil
	local titled = false
	if delta then
		titled = true
		b.add("compareTitle", Locale.T("tooltip.compare", nil, lang), "muted")
		for _, axis in PCT_AXES do
			local v: number = (delta :: any)[axis]
			if math.abs(v) >= 0.05 then
				b.add(
					"comparePct",
					Locale.T(`tooltip.compare.{axis}`, { v = signedPct(v, lang) }, lang),
					"dark",
					{ hex = if v > 0 then "#2E8B3E" else "#B8423A", font = "bold" }
				)
			end
		end
		b.add("compareNote", Locale.T("tooltip.compare.estimate", nil, lang), "muted", { size = "small" })
		if offhand then
			local name = ItemName.get(lang, offhand.id, offhand.up, ItemRoll.elementOf(offhand))
			b.add(
				"compareNote",
				Locale.T("tooltip.compare.offhand", { item = name }, lang),
				"muted",
				{ size = "small" }
			)
		end
	end
	if equipped then
		compareLines(b, item, equipped, lang, titled)
	end
end

-- Builds the tooltip lines of `item` (def defaults to Items.get(item.id)).
function TooltipModel.build(item: ItemInstance, def: ItemDef?, ctx: Ctx?): Model
	local c: Ctx = ctx or {}
	local lang = c.lang or Locale.getLanguage()
	local b = builder()
	local itemDef = def or Items.get(item.id)
	if not itemDef then
		b.add("name", Locale.T("item.unknown", nil, lang))
		return { lines = b.lines }
	end
	local d = itemDef :: ItemDef

	-- Header
	local rarity = Rarities.get(item.rarity)
	local element = ItemRoll.elementOf(item)
	b.add(
		"name",
		ItemName.get(lang, item.id, item.up, element),
		"rarity",
		{ hex = rarity.textHex, size = "large", font = "heading" }
	)
	b.add(
		"type",
		`<font color="{rarity.textHex}"><b>{Locale.T(rarity.nameKey, nil, lang)}</b></font> · {Locale.T(
			TooltipModel.categoryKey(d),
			nil,
			lang
		)}`,
		"muted"
	)

	-- Statistics / effect
	local described = false
	local use = d.use
	if d.category == "equipment" then
		local stats = ItemRoll.itemStats(item)
		equipmentStats(b, item, stats, lang)
		traitLines(b, stats, lang)
		bonusLines(b, stats, lang)
	elseif d.category == "backpack" then
		b.add("effect", Locale.T("tooltip.capacity", { capacity = d.capacity or 0 }, lang), "dark", { font = "bold" })
	elseif d.category == "material" then
		materialLines(b, d, lang)
		described = true
	elseif d.category == "tool" then
		described = toolLines(b, d, lang)
	elseif use and use.kind == "potion" and use.resource then
		b.add(
			"effect",
			Locale.T(`tooltip.restores.{use.resource}`, { amount = Format.number(use.amount or 0) }, lang),
			"dark",
			{ font = "bold" }
		)
	elseif use and use.kind == "blessing" then
		blessingLines(b, d, lang)
	elseif use and use.kind == "elixir" then
		elixirLines(b, d, lang)
	else
		described = useEffectLines(b, d, lang)
	end
	if d.descKey and not described then
		b.add("desc", `<i>{Locale.T(d.descKey, nil, lang)}</i>`, "muted")
	end

	-- Requirements
	local required = ItemRoll.requiredLevel(item)
	if required > 1 then
		local met = c.level == nil or c.level >= required
		b.add("requires", Locale.T("tooltip.requiresLevel", { level = required }, lang), if met then "dark" else "bad")
	end
	if d.classes then
		local names = {}
		for _, id in d.classes do
			local class = Classes.get(id)
			table.insert(names, if class then Locale.T(class.nameKey, nil, lang) else id)
		end
		local ok = c.class == nil or table.find(d.classes, c.class) ~= nil
		b.add(
			"classes",
			Locale.T("tooltip.classes", { classes = table.concat(names, ", ") }, lang),
			if ok then "dark" else "bad"
		)
	end

	if d.slot and d.slot ~= "backpack" then
		comparison(b, item, d, c, lang)
	end

	-- Binding
	if d.category == "equipment" then
		if item.bound then
			b.add("bind", Locale.T("tooltip.bound", nil, lang), "bad")
		elseif d.bindOnPickup or rarity.bindOnPickup then
			b.add("bind", Locale.T("tooltip.bindOnPickup", nil, lang), "muted")
		else
			b.add("bind", Locale.T("tooltip.bindOnEquip", nil, lang), "muted")
		end
	end
	if item.n > 1 then
		b.add("stack", Locale.T("tooltip.stack", { n = item.n }, lang), "muted")
	end

	-- Value and context price
	local value = ItemValue.value(item, d)
	local valueText = Locale.T("tooltip.value", { price = gold(value) }, lang)
	if item.n > 1 then
		valueText ..= " " .. Locale.T("tooltip.valueEach", { price = gold(value // item.n) }, lang)
	end
	b.add("value", valueText, "dark", { font = "bold" })
	if c.shopEntry then
		local price = ShopPrice.unit(c.shopEntry, c.level or 1, c.potionDiscount, c.shop)
		b.add("price", Locale.T("tooltip.buyPrice", { price = gold(price) }, lang), "dark", { font = "bold" })
	elseif not ItemValue.canSell(item, d) then
		b.add("noSell", Locale.T("tooltip.noSell", nil, lang), "bad")
	elseif c.merchantOpen then
		b.add("sellFor", Locale.T("tooltip.sellFor", { price = gold(ItemValue.sellPrice(item, d)) }, lang), "good")
	end

	-- S68: how to open the details of a row (only when the caller says which input is used).
	if c.input then
		local any = false
		for _, entry in b.lines do
			if entry.detail then
				any = true
				break
			end
		end
		if any then
			local text = if c.input == "touch"
				then Locale.T("tooltip.detailsHint.touch", nil, lang)
				else Locale.T("tooltip.detailsHint.mouse", { key = c.detailsKey or "Alt" }, lang)
			b.add("detailsHint", text, "muted", { size = "small" })
		end
	end

	-- Action hint
	local hints = if c.hints ~= nil then c.hints else c.shopEntry == nil
	if hints then
		if d.slot then
			b.add("hint", Locale.T("tooltip.hintEquip", nil, lang), "muted")
		elseif use and use.kind ~= "none" then
			b.add("hint", Locale.T("tooltip.hintUse", nil, lang), "muted")
		end
	end
	return { lines = b.lines }
end

-- Details panel (S68, STATY 11) ------------------------------------------------------------------------------

-- The number behind a cap reference; nil when the key is unknown (tooltip.spec keeps every reference resolvable).
function TooltipModel.capValue(ref: Types.CapRef): number?
	local value: any = nil
	if ref.source == "stat" then
		local def = Stats.get(ref.key)
		value = def and def.cap
	elseif ref.source == "combat" then
		value = (Combat :: any)[ref.key]
	elseif ref.source == "category" then
		value = BuffCategories.caps[ref.key]
	elseif ref.source == "luck" then
		value = (Luck :: any)[ref.key]
	end
	return if type(value) == "number" then value else nil
end

-- A multiplier like "0,6" (at most two decimals, trailing zeros dropped).
local function fraction(value: number, lang: string): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return if lang == "pl" then (string.gsub(text, "%.", ",")) else text
end

-- Cap text: stats format like the Character window, everything else as a percentage.
local function capText(ref: Types.CapRef, lang: string): string?
	local cap = TooltipModel.capValue(ref)
	if not cap then
		return nil
	end
	if ref.source == "stat" then
		return formatStat(ref.key, cap, lang)
	end
	return traitNumber(cap, lang) .. "%"
end

-- The cap of a bonus line: its capRef, else the cap of its stat in Data/Stats.
local function bonusCap(def: Bonuses.BonusDef, lang: string): string?
	if def.capRef then
		return capText(def.capRef, lang)
	end
	local stat = def.stat and (ALIASES[def.stat] or def.stat)
	local statDef = stat and Stats.get(stat)
	if statDef and statDef.cap then
		return formatStat(statDef.id, statDef.cap, lang)
	end
	return nil
end

local function effectOf(def: Bonuses.BonusDef): string
	local effect = def.hook or def.stat or def.id
	return ALIASES[effect] or effect
end

local function className(classId: string, lang: string): string
	local class = Classes.get(classId)
	return if class then Locale.T(class.nameKey, nil, lang) else classId
end

-- "Better item" counts the line at half (Data/ItemWeights: situational hook or prefix).
local function situational(def: Bonuses.BonusDef): boolean
	local hook = def.hook
	if not hook then
		return false
	end
	local weight = ItemWeights.hooks[hook]
	if weight then
		return weight.situational == true
	end
	for prefix, w in ItemWeights.prefixHooks do
		if string.sub(hook, 1, #prefix) == prefix then
			return w.situational == true
		end
	end
	return false
end

local function valueText(def: Bonuses.BonusDef, value: number, lang: string): string
	return if def.decimals == 0 then tostring(math.floor(value + 0.5)) else decimal(value, def.decimals, lang)
end

local function bonusDetails(item: ItemInstance, id: string, v: number, quality: number?, lang: string): Details
	local def = Bonuses.get(id)
	if not def then
		return { title = id, tier = "regular", rows = {} }
	end
	local rows: { DetailRow } = {}
	local cap = bonusCap(def, lang)
	local mode = def.pvp or "same"
	local pvpValue = if mode == "ticks"
		then Combat.pvp.dot
		elseif mode == "half" then (Combat.pvp :: any)[effectOf(def)] or Combat.pvpModifier
		else Combat.pvpModifier
	local args: { [string]: any } = {
		cap = cap or "",
		pvp = fraction(pvpValue, lang),
		threshold = math.floor(Combat.lowHpFraction * 100 + 0.5),
		gap = traitNumber(Combat.resourceOnHitGap, lang),
	}

	-- does
	local param = def.param and Bonuses.params[def.param]
	local does: string
	if param and def.of then
		local key = if param.over == "family"
			then (if param.prefix == "vs_" then "bonusInfo.vsFamily" else "bonusInfo.resFamily")
			else (if param.prefix == "vs_" then "bonusInfo.vsClass" else "bonusInfo.resClass")
		args.family = if param.over == "family" then Locale.T(`family.{def.of}`, nil, lang) else nil
		args.class = if param.over == "class" then className(def.of, lang) else nil
		does = Locale.T(key, args, lang)
	else
		local key = `bonusInfo.{effectOf(def)}`
		if Locale.has(key, lang) then
			does = Locale.T(key, args, lang)
		else
			local stat = statName(lang, def.stat or def.id)
			local shown = valueText(def, v, lang)
			if def.mode == "pct" then
				does = Locale.T("tooltip.detail.statPct", { stat = stat, v = shown }, lang)
			else
				does = Locale.T(
					"tooltip.detail.statAdd",
					{ stat = stat, v = if def.percent then shown .. "%" else shown },
					lang
				)
			end
		end
	end
	table.insert(rows, { role = "does", text = does, tone = "dark" })

	-- range
	local itemDef = Items.get(item.id)
	if itemDef and itemDef.fixedBonuses then
		table.insert(rows, { role = "range", text = Locale.T("tooltip.detail.fixed", nil, lang), tone = "muted" })
	else
		local low, high = ItemRoll.bonusRange(id, item.ilvl, item.rarity)
		local q = quality or ItemRoll.bonusQuality(id, v, item.ilvl, item.rarity)
		table.insert(rows, {
			role = "range",
			text = Locale.T("tooltip.detail.range", {
				min = valueText(def, low, lang),
				max = valueText(def, high, lang),
				q = math.floor(math.clamp(q, 0, 1) * 100 + 0.5),
			}, lang),
			tone = "muted",
		})
	end

	if cap then
		table.insert(rows, { role = "cap", text = Locale.T("tooltip.detail.cap", { cap = cap }, lang), tone = "muted" })
	end
	table.insert(
		rows,
		{ role = "pvp", text = Locale.T(`tooltip.detail.pvp.{mode}`, { pvp = args.pvp }, lang), tone = "muted" }
	)
	if situational(def) then
		table.insert(
			rows,
			{ role = "situational", text = Locale.T("tooltip.detail.situational", nil, lang), tone = "muted" }
		)
	end
	return { title = bonusText(lang, id, v), tier = def.tier, rows = rows }
end

-- Path nodes whose passive hooks strengthen a trait (ItemTraits nodeHooks), in path and row order. `paths` is
-- Data/Paths.list in the game (tests pass their own).
function TooltipModel.traitNodes(
	traitId: string,
	paths: { any },
	owned: { [string]: number }?,
	lang: string
): { TraitNode }
	local def = ItemTraits.get(traitId)
	local hooks: { string } = if def and def.nodeHooks then def.nodeHooks else {}
	local out: { TraitNode } = {}
	if #hooks == 0 then
		return out
	end
	local have: { [string]: number } = owned or {}
	for _, path in paths do
		for _, row in path.rows or {} do
			for _, node in row.nodes or {} do
				local nodeHooks = node.passive and node.passive.hooks
				local match = false
				if nodeHooks then
					for _, hook in hooks do
						if nodeHooks[hook] ~= nil then
							match = true
							break
						end
					end
				end
				if match then
					table.insert(out, {
						path = Locale.T(path.nameKey, nil, lang),
						node = Locale.T(node.nameKey, nil, lang),
						nodeId = node.id,
						owned = (have[node.id] or 0) > 0,
					})
				end
			end
		end
	end
	return out
end

local function traitDetails(item: ItemInstance, traitId: string, c: Ctx, lang: string): Details
	local def = ItemTraits.get(traitId)
	if not def then
		return { title = traitId, tier = "trait", rows = {} }
	end
	local roll = ItemRoll.trait(item)
	local power = if roll and roll.id == traitId then roll.power else ItemRoll.traitPower(item.rarity, item.up)
	local args: { [string]: any } = TooltipModel.traitArgs(traitId, power, lang)
	args.dot = fraction(Combat.pvp.dot, lang)
	args.frost = fraction(Combat.pvp.frostbite, lang)
	local rows: { DetailRow } = {}
	table.insert(rows, { role = "does", text = Locale.T(`trait.{traitId}.info`, args, lang), tone = "dark" })
	table.insert(
		rows,
		{ role = "growth", text = Locale.T("tooltip.detail.traitPower", { power = decimal(power, 2, lang) }, lang) }
	)
	-- Full Draw: the bonus with the equipped weapon's speed (the server uses the same Traits.drawBonus).
	local main = c.mainHand
	local weapon = main and ItemRoll.itemStats(main).weapon
	if def.hook == "traitFullDraw" and main and weapon then
		local bonus = Traits.drawBonus(def.value * power, weapon.speed)
		table.insert(rows, {
			role = "weapon",
			text = Locale.T("tooltip.detail.quiverMain", {
				weapon = ItemName.get(lang, main.id, main.up, ItemRoll.elementOf(main)),
				v = traitNumber(bonus, lang),
			}, lang),
		})
	end
	local cap = def.capRef and capText(def.capRef, lang)
	if cap then
		table.insert(rows, { role = "cap", text = Locale.T("tooltip.detail.cap", { cap = cap }, lang), tone = "muted" })
	end
	local pvpKey = `trait.{traitId}.pvp`
	local pvp = if Locale.has(pvpKey, lang)
		then Locale.T(pvpKey, args, lang)
		elseif def.pvp <= 0 then Locale.T("tooltip.detail.pvp.none", nil, lang)
		elseif def.pvp >= 1 then Locale.T(
			"tooltip.detail.pvp.same",
			{ pvp = fraction(Combat.pvpModifier, lang) },
			lang
		)
		else Locale.T("tooltip.detail.pvp.mul", { mul = fraction(def.pvp, lang) }, lang)
	table.insert(rows, { role = "pvp", text = pvp, tone = "muted" })
	local nodes = TooltipModel.traitNodes(traitId, PathData.list, c.nodes, lang)
	if #nodes > 0 then
		local names: { string } = {}
		for _, node in nodes do
			local text = `{node.node} ({node.path})`
			table.insert(names, if node.owned then `<b>{text}</b>` else text)
		end
		table.insert(
			rows,
			{ role = "nodes", text = Locale.T("tooltip.detail.nodes", { list = table.concat(names, ", ") }, lang) }
		)
	end
	return { title = Locale.T(def.nameKey, nil, lang), tier = "trait", rows = rows }
end

-- The details of one row of `item`'s tooltip (a bonus line or the trait): what it does, its range, cap and PvP rule.
function TooltipModel.details(item: ItemInstance, ref: DetailRef, ctx: Ctx?): Details
	local c: Ctx = ctx or {}
	local lang = c.lang or Locale.getLanguage()
	if ref.kind == "trait" then
		return traitDetails(item, ref.id, c, lang)
	end
	local bonus = ref :: { kind: "bonus", id: string, v: number, quality: number? }
	return bonusDetails(item, bonus.id, bonus.v, bonus.quality, lang)
end

-- Compact one-line summary for shop rows (S31 C.2), e.g. "Poz. 15 · Obr. 39 · 1,20/s · DPS 46,8".
-- Weapons: level, damage, speed, DPS; other equipment: level + main base stats; backpacks: slots + level;
-- potions / elixirs: their effect. nil when there is nothing short to say.
function TooltipModel.statLine(item: ItemInstance, def: ItemDef?, lang: string?): string?
	local language = lang or Locale.getLanguage()
	local d = def or Items.get(item.id)
	if not d then
		return nil
	end
	local parts: { string } = {}
	local required = ItemRoll.requiredLevel(item)
	if d.category == "equipment" then
		table.insert(parts, Locale.T("itemLine.level", { level = required }, language))
		local stats = ItemRoll.itemStats(item)
		local w = stats.weapon
		if w then
			if w.dmg > 0 then
				table.insert(parts, Locale.T("itemLine.dmg", { dmg = w.dmg }, language))
			end
			if w.mdmg > 0 then
				table.insert(parts, Locale.T("itemLine.mdmg", { mdmg = w.mdmg }, language))
			end
			table.insert(parts, Locale.T("itemLine.speed", { speed = decimal(w.speed, 2, language) }, language))
			table.insert(parts, Locale.T("itemLine.dps", { dps = decimal(TooltipModel.dps(w), 1, language) }, language))
		else
			local keys = {}
			for stat in stats.base do
				table.insert(keys, stat)
			end
			table.sort(keys)
			for _, stat in keys do
				table.insert(
					parts,
					Locale.T(
						"itemLine.stat",
						{ stat = statName(language, stat), value = formatStat(stat, stats.base[stat], language) },
						language
					)
				)
			end
		end
	elseif d.category == "backpack" then
		table.insert(parts, Locale.T("itemLine.capacity", { capacity = d.capacity or 0 }, language))
		if required > 1 then
			table.insert(parts, Locale.T("itemLine.level", { level = required }, language))
		end
	else
		local use = d.use
		if use and use.kind == "potion" and use.resource then
			return Locale.T(`tooltip.restores.{use.resource}`, { amount = Format.number(use.amount or 0) }, language)
		elseif use and use.kind == "elixir" and use.target then
			return Locale.T(
				"tooltip.elixir",
				{ stat = statName(language, use.target), value = Blessings.ELIXIR_VALUE },
				language
			)
		end
		return nil
	end
	return table.concat(parts, " · ")
end

-- Plain text of a line (rich text tags removed), for the admin dump and tests.
function TooltipModel.plain(text: string): string
	return (string.gsub(text, "<[^>]+>", ""))
end

return TooltipModel
