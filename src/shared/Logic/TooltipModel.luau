--!strict
-- Item tooltip content (S31, DESIGN §5, §23) as a pure list of lines, so every category can be tested in Lune.
-- `UI/Components/ItemTooltip` only draws the lines. S134g (owner 2026-10-15): every item gets the same header (name in
-- the rarity colour, the head line "Kind · Category · Level N · Classes" with the unmet part in red, the rarity and
-- upgrade in small type), then its main value, the statistics in small type in fixed groups, the trait, the skill
-- effects, the description and the value line ("Value: X gold") with the context price. No comparison numbers: the
-- comparison is the second panel with the equipped item (ItemTooltip); only "Replaces: <name>" and the two-hander note.
--
-- ctx (every field optional):
--   lang: string           -- "pl" | "en" (default: Locale's current language)
--   level: number          -- character level (the level in the head line turns red when higher; nil = met)
--   class: string          -- character class id (classes in the head line; effects of another class say so)
--   equipped: ItemInstance -- the equipped item it would replace ("Replaces: <name>")
--   shop: Shops.ShopDef    -- shop the item is offered in
--   shopEntry: Shops.Entry -- the offered entry: adds "Price: X gold" (ShopPrice.unit, the same as the row)
--   potionDiscount: number -- guild potion discount (derived stat), for the shop price
--   merchantOpen: boolean  -- a merchant window is open: backpack items add "Sells for: X gold"
--   hints: boolean         -- false hides the "double click: equip/use" hint (default: shown outside shops)
--   pathId: string         -- S68: character.path.main
--   nodes: {[id]: number}  -- S68: character.path.nodes (owned nodes are marked in trait details)
--   mainHand: ItemInstance -- S68: equipped weapon (Full Draw details; an off-hand against a two-hander)
--   offhand: ItemInstance  -- S68: equipped off-hand (a two-handed candidate also replaces it)
--   input: "mouse"|"touch" -- S68: picks the details hint; nil = no hint (tests, admin dump)
--   detailsKey: string     -- S68: label of the details key on PC (Keybinds.label("item_details"))
--
-- Line fields: `text` (may hold rich text), `role` (what the line is, for tests and the admin dump), `tone`
-- (colour role), `hex` (explicit colour, overrides tone), `size`, `font`; bonus rows have `kind = "bonus"`,
-- `quality` 0..1, `tier` (Data/Bonuses) and `legendary` / `mythic` from it. S62: weapons and off-hands get a "Trait"
-- section (name + line, Data/ItemTraits colour), only for live traits. S134g roles: `head`, `rarity`, `speedDps`,
-- `gap` (a thin space between stat groups), `fxTitle` / `fx` / `fxClass` (skill effects), `replaces`, `compareNote`.
-- Every bonus, trait and effect row carries a `detail` reference that `TooltipModel.details` turns into the details
-- panel (S68).

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
local ItemEffects = require("./ItemEffects")
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
-- S134g: or a skill effect of the item (Data/ItemEffects id).
export type DetailRef =
	{ kind: "bonus", id: string, v: number, quality: number? }
	| { kind: "trait", id: string }
	| { kind: "effect", id: string }
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

-- S68 (STATY 11): the order of the line tiers (S134g: rows sort by STAT_GROUPS; the tier styles legacy lines).
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
			-- S134g (owner 2026-10-15): the grip is always said, ranged weapons too
			local weapon = def.weapon
			if weapon and weapon.ranged then
				return if weapon.twoHanded then "itemCat.weaponRanged2h" else "itemCat.weaponRanged1h"
			elseif weapon and weapon.twoHanded then
				return "itemCat.weapon2h"
			end
			return "itemCat.weapon1h"
		end
		return `itemCat.{def.slot or "equipment"}`
	elseif def.category == "consumable" then
		local kind = if def.use then def.use.kind else "potion"
		if kind == "blessing" or kind == "elixir" or kind == "fullElixir" then -- S122: fullElixir
			return `itemCat.{kind}`
		end
		return "itemCat.potion"
	end
	return `itemCat.{def.category}`
end

-- S134g (F1): red of an unmet part of the head line (the ItemTooltip BAD colour).
TooltipModel.BAD_HEX = "#B8423A"

-- The kind of the item (Miecz, Kurta ...) and its category (Broń jednoręczna, Zbroja ...); the kind is left out when it
-- says the same as the category (Pierścień · Pierścień) and for everything but equipment.
function TooltipModel.kindParts(d: ItemDef, lang: string): { string }
	local parts: { string } = {}
	local category = Locale.T(TooltipModel.categoryKey(d), nil, lang)
	local baseKey = if d.category == "equipment" and d.type then `itemBase.{d.type}` else nil
	if baseKey and Locale.has(baseKey, lang) then
		local base = Locale.T(baseKey, nil, lang)
		if string.lower(base) ~= string.lower(category) then
			table.insert(parts, base)
		end
	end
	table.insert(parts, category)
	return parts
end

-- S134g (F1, owner 2026-10-15): the second line of every tooltip, "Kind · Category · Level N · Classes". The level
-- (ItemRoll.requiredLevel) is left out at 1, the classes when the item has none; the part the character does not meet
-- is red (`level` / `class` of the context; nil = met).
function TooltipModel.headLine(item: ItemInstance, d: ItemDef, c: Ctx, lang: string): string
	local parts = TooltipModel.kindParts(d, lang)
	local function red(text: string, met: boolean): string
		return if met then text else `<font color="{TooltipModel.BAD_HEX}">{text}</font>`
	end
	local required = ItemRoll.requiredLevel(item)
	if required > 1 then
		local met = c.level == nil or c.level >= required
		table.insert(parts, red(Locale.T("tooltip.head.level", { level = required }, lang), met))
	end
	if d.classes and #d.classes > 0 then
		local names = {}
		for _, id in d.classes do
			local class = Classes.get(id)
			table.insert(names, if class then Locale.T(class.nameKey, nil, lang) else id)
		end
		local met = c.class == nil or table.find(d.classes, c.class) ~= nil
		table.insert(parts, red(table.concat(names, ", "), met))
	end
	return table.concat(parts, " · ")
end

-- S134g (F1): the rarity in its colour and the upgrade ("Legendarny · +3"); a stack shows the rarity alone.
function TooltipModel.rarityLine(item: ItemInstance, d: ItemDef, lang: string): string
	local rarity = Rarities.get(item.rarity)
	local text = `<font color="{rarity.textHex}"><b>{Locale.T(rarity.nameKey, nil, lang)}</b></font>`
	if d.category == "equipment" and (item.up or 0) > 0 then
		text ..= ` · +{item.up}`
	end
	return text
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

-- S134g (F1): the fixed groups of the statistics block, in order; inside a group the order of `keys` (StatCalc stat or
-- hook ids after Data/Bonuses: a line reads as its `stat` or `hook`, hp / mana / energy as maxHp / maxMana /
-- maxEnergy) and `prefixes` (lines with a parameter). Not balance numbers (CLAUDE.md): only the reading order.
-- Every published line of Data/Bonuses has a group (tooltip.spec); anything else goes last.
TooltipModel.STAT_GROUPS = table.freeze({
	{ id = "attributes", keys = { "str", "dex", "int", "vit" }, prefixes = {} },
	{
		id = "attack",
		keys = {
			"physAtk",
			"magAtk",
			"critChance",
			"critDmg",
			"atkSpeed",
			"pierce",
			"magicPierce",
			"accuracy",
			"skillDmg",
			"basicDmg",
			"lifesteal",
			"woundChance",
			"poisonChance",
			"dotPower",
		},
		prefixes = { "vs_" },
	},
	{
		id = "defence",
		keys = {
			"maxHp",
			"armor",
			"mres",
			"resFire",
			"resIce",
			"resLightning",
			"resPoison",
			"block",
			"dodge",
			"critResist",
			"meleeGuard",
			"rangedGuard",
		},
		prefixes = { "res_" },
	},
	{
		id = "resources",
		keys = {
			"maxMana",
			"maxEnergy",
			"hpRegen",
			"manaRegen",
			"energyRegen",
			"resourceOnHit",
			"costReduce",
			"healPower",
			"moveSpeed",
			"dropBonus",
			"expBonus",
			"goldBonus",
		},
		prefixes = {},
	},
})

-- The StatCalc stat or hook a line id or base key reads as (aliases applied).
local function readKey(key: string): string
	local bonus = Bonuses.get(key)
	if bonus then
		local read = if bonus.replacedBy then Bonuses.get(bonus.replacedBy) or bonus else bonus
		local id = read.hook or read.stat or key
		return ALIASES[id] or id
	end
	local id = ItemRoll.baseKey(key)
	return ALIASES[id] or id
end

-- S134g: (group index, place in the group) of a line id or base key; nil when no group lists it.
function TooltipModel.groupOf(key: string): (number?, number?)
	local read = readKey(key)
	for index, group in TooltipModel.STAT_GROUPS do
		local at = table.find(group.keys, read)
		if at then
			return index, at
		end
		for p, prefix in group.prefixes do
			if string.sub(read, 1, #prefix) == prefix then
				return index, #group.keys + p
			end
		end
	end
	return nil, nil
end

-- The main value of a non-weapon item: its armour; everything else goes to the grouped statistics.
local MAIN_BASE = "armor"

-- Equipment main block: element, then weapon damage with speed and DPS in one line, or the armour of the base (FIX
-- 2026-10-15: the item level is in the footer; S134g: the grip, level and classes are in the head line).
local function mainValue(b: Builder, item: ItemInstance, stats: ItemRoll.ItemStats, lang: string)
	local element = ItemRoll.elementOf(item)
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
		local speed = Locale.T("tooltip.speed", { speed = decimal(w.speed, 2, lang) }, lang)
		local dps = Locale.T("tooltip.dps", { dps = decimal(TooltipModel.dps(w), 1, lang) }, lang)
		b.add("speedDps", `{speed} · {dps}`, "dark")
	elseif stats.base[MAIN_BASE] then
		b.add(
			"stat",
			`{statName(lang, MAIN_BASE)}: <b>{formatStat(MAIN_BASE, stats.base[MAIN_BASE], lang)}</b>`,
			"dark",
			{ size = "body" }
		)
	end
end

local function tierOf(id: string): Tier
	local def = Bonuses.get(id)
	return if def then def.tier else "regular"
end

-- S134g (F1): the statistics in small type, in the fixed groups (TooltipModel.STAT_GROUPS) with a thin gap between
-- groups: the base stats besides the main value, then every line of the item (in a group the list's order, never the
-- roll's; a base stat before a line of the same stat). The quality bar stays on the lines; the rarity bonus last.
local function groupedStats(b: Builder, item: ItemInstance, stats: ItemRoll.ItemStats, lang: string)
	type Row = { group: number, place: number, base: boolean, index: number, line: Line }
	local rows: { Row } = {}
	local others = #TooltipModel.STAT_GROUPS + 1
	local keys: { string } = {}
	for stat in stats.base do
		if stats.weapon ~= nil or stat ~= MAIN_BASE then
			table.insert(keys, stat)
		end
	end
	table.sort(keys)
	for index, stat in keys do
		local group, place = TooltipModel.groupOf(stat)
		table.insert(rows, {
			group = group or others,
			place = place or 0,
			base = true,
			index = index,
			line = {
				kind = "text",
				role = "stat",
				text = `{statName(lang, stat)}: <b>{formatStat(stat, stats.base[stat], lang)}</b>`,
				tone = "dark",
				size = "small",
			},
		})
	end
	for index, bonus in stats.bonuses do
		local group, place = TooltipModel.groupOf(bonus.id)
		local tier: Tier = tierOf(bonus.id)
		table.insert(rows, {
			group = group or others,
			place = place or 0,
			base = false,
			index = index,
			line = {
				kind = "bonus",
				role = "bonus",
				text = bonusText(lang, bonus.id, bonus.v),
				tone = "bonus",
				size = "small",
				quality = bonus.quality,
				legendary = tier == "legendary",
				mythic = tier == "mythic",
				tier = tier,
				detail = { kind = "bonus", id = bonus.id, v = bonus.v, quality = bonus.quality } :: DetailRef,
			},
		})
	end
	table.sort(rows, function(x: Row, y: Row): boolean
		if x.group ~= y.group then
			return x.group < y.group
		elseif x.place ~= y.place then
			return x.place < y.place
		elseif x.base ~= y.base then
			return x.base
		end
		return x.index < y.index
	end)
	local last: number? = nil
	for _, row in rows do
		if last ~= nil and row.group ~= last then
			b.add("gap", "", "muted")
		end
		last = row.group
		table.insert(b.lines, row.line)
	end
	-- FIX 2026-10-15 (owner): what the rarity adds, said outright (base x Rarities.baseMul, already inside the numbers
	-- above); named boss items carry their own fixed numbers.
	local def = Items.get(item.id)
	local rarity = Rarities.get(item.rarity)
	if def and def.fixedBonuses == nil and rarity.baseMul > 1 then
		local pct = math.floor((rarity.baseMul - 1) * 100 + 0.5)
		b.add("rarityBonus", Locale.T("tooltip.rarityBonus", { pct = pct }, lang), "muted", { size = "small" })
	end
end

-- S62 (STATY 11): the trait section, after the statistics and before the effects.
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

local function className(classId: string, lang: string): string
	local class = Classes.get(classId)
	return if class then Locale.T(class.nameKey, nil, lang) else classId
end

-- S134g (F1): the skill effects after the trait: a title in the tier's colour ("Efekt legendarny: <name>") and the
-- effect's line; an effect of another class than the viewer's says whom it works for.
local function effectLines(b: Builder, item: ItemInstance, c: Ctx, lang: string)
	for _, effect in ItemEffects.ofItem(item, c.class) do
		local detail: DetailRef = { kind = "effect", id = effect.id }
		local hex = Rarities.get(if effect.tier == "mythic" then Rarities.MYTHIC else Rarities.LEGENDARY).textHex
		b.add(
			"fxTitle",
			Locale.T(`tooltip.fx.{effect.tier}`, { name = Locale.T(effect.nameKey, nil, lang) }, lang),
			"legendary",
			{ hex = hex, font = "bold", detail = detail, tier = effect.tier }
		)
		b.add("fx", ItemEffects.line(effect, lang), "dark", { detail = detail, tier = effect.tier })
		if c.class ~= nil and effect.class ~= c.class then
			b.add(
				"fxClass",
				Locale.T("tooltip.fx.otherClass", { class = className(effect.class, lang) }, lang),
				"muted",
				{ size = "small" }
			)
		end
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

local function isTwoHanded(item: ItemInstance): boolean
	local weapon = ItemRoll.itemStats(item).weapon
	return weapon ~= nil and weapon.twoHanded
end

-- S134g (F2, owner 2026-10-15): the comparison is the second panel with the equipped item's own tooltip (ItemTooltip),
-- so the tooltip says no numbers about it: only that an off-hand cannot go next to a two-hander (red) and what the item
-- would replace ("Replaces: <name>", a two-hander also the off-hand).
local function replaceNotes(b: Builder, item: ItemInstance, d: ItemDef, c: Ctx, lang: string)
	local equipped = c.equipped
	if equipped and equipped.uid == item.uid then
		return
	end
	if d.slot == "offhand" and c.mainHand and isTwoHanded(c.mainHand) then
		b.add("compareNote", Locale.T("equip.error.twoHanded", nil, lang), "bad")
		return
	end
	local names: { string } = {}
	if equipped then
		table.insert(names, ItemName.get(lang, equipped.id, equipped.up, ItemRoll.elementOf(equipped)))
	end
	local offhand = c.offhand
	if d.slot == "weapon" and offhand and offhand.uid ~= item.uid and isTwoHanded(item) then
		table.insert(names, ItemName.get(lang, offhand.id, offhand.up, ItemRoll.elementOf(offhand)))
	end
	if #names > 0 then
		b.add("replaces", Locale.T("tooltip.replaces", { item = table.concat(names, ", ") }, lang), "muted")
	end
end

-- Builds the tooltip lines of `item` (def defaults to Items.get(item.id)). S134g (F1, docs/DESIGN.md §23): name, head
-- ("Kind · Category · Level N · Classes"), rarity (small), the main value, the statistics in small type in fixed
-- groups, the rarity bonus, the trait, the skill effects, the description, the replace notes, binding, stack, item
-- level, value / price, the details hint and the action hint. Every category has the same first three lines.
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
	b.add("head", TooltipModel.headLine(item, d, c, lang), "dark", { size = "body", font = "bold" })
	b.add("rarity", TooltipModel.rarityLine(item, d, lang), "muted", { size = "small" })

	-- Statistics / effect
	local described = false
	local use = d.use
	if d.category == "equipment" then
		local stats = ItemRoll.itemStats(item)
		mainValue(b, item, stats, lang)
		groupedStats(b, item, stats, lang)
		traitLines(b, stats, lang)
		effectLines(b, item, c, lang)
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
	elseif use and use.kind == "fullElixir" then
		-- S122 (DESIGN-17 §3): what it does, its limits and where it does not work (Logic/UseBlocks.LISTS.fullElixir)
		b.add("effect", Locale.T("tooltip.fullElixir.effect", nil, lang), "dark", { font = "bold" })
		b.add(
			"rules",
			Locale.T(
				"tooltip.fullElixir.rules",
				{ min = Config.FullElixir.cooldown // 60, n = Config.FullElixir.dailyLimit },
				lang
			),
			"dark"
		)
		b.add("blocked", Locale.T("tooltip.fullElixir.blocked", { s = Config.PvpCombatLock }, lang), "bad")
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

	if d.slot and d.slot ~= "backpack" then
		replaceNotes(b, item, d, c, lang)
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
	elseif item.bound then
		-- S122: bound stacks too (the Elixir of Wholeness is bound from creation; worn backpacks)
		b.add("bind", Locale.T("tooltip.bound", nil, lang), "bad")
	end
	if item.n > 1 then
		b.add("stack", Locale.T("tooltip.stack", { n = item.n }, lang), "muted")
	end
	-- FIX 2026-10-15: the item level is a detail (the requirement above says what matters): footer, small.
	if d.category == "equipment" then
		b.add("ilvl", Locale.T("tooltip.ilvl", { ilvl = item.ilvl }, lang), "muted", { size = "small" })
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
		-- S87: the range of a two-handed line as its shown value (x twoHandedBonusMul); quality from the saved roll
		local lineMul = ItemRoll.lineMultiplier(item, id)
		low, high = low * lineMul, high * lineMul
		local q = quality or ItemRoll.bonusQuality(id, v / lineMul, item.ilvl, item.rarity)
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

-- S134g (F1): the details of a skill effect: what it does, the skill it changes, that it works with breakpoints and
-- nodes, that the same effect from two items works once, and the class it works for.
local function effectDetails(id: string, lang: string): Details
	local def = ItemEffects.resolve(id)
	if not def then
		return { title = id, tier = "legendary", rows = {} }
	end
	local args = ItemEffects.lineArgs(def, lang)
	return {
		title = Locale.T(def.nameKey, nil, lang),
		tier = def.tier,
		rows = {
			{ role = "does", text = ItemEffects.line(def, lang), tone = "dark" },
			{
				role = "skill",
				text = Locale.T("tooltip.details.fx.skill", { skill = args.skill }, lang),
				tone = "dark",
			},
			{ role = "works", text = Locale.T("tooltip.details.fx.works", nil, lang), tone = "muted" },
			{ role = "once", text = Locale.T("tooltip.details.fx.once", nil, lang), tone = "muted" },
			{
				role = "class",
				text = Locale.T("tooltip.details.fx.class", { class = className(def.class, lang) }, lang),
				tone = "muted",
			},
		},
	}
end

-- The details of one row of `item`'s tooltip (a bonus line, the trait or a skill effect): what it does, its range, cap
-- and PvP rule.
function TooltipModel.details(item: ItemInstance, ref: DetailRef, ctx: Ctx?): Details
	local c: Ctx = ctx or {}
	local lang = c.lang or Locale.getLanguage()
	if ref.kind == "trait" then
		return traitDetails(item, ref.id, c, lang)
	elseif ref.kind == "effect" then
		return effectDetails(ref.id, lang)
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
		elseif use and use.kind == "fullElixir" then
			return Locale.T("tooltip.fullElixir.effect", nil, language)
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
