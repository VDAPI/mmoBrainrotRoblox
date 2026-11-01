--!strict
-- Item tooltip content (S31, DESIGN §5, §23) as a pure list of lines, so every category can be tested in Lune.
-- `UI/Components/ItemTooltip` only draws the lines. S134g (owner 2026-10-15): every item gets the same header (name in
-- the rarity colour, the head line "Kind · Category · Level N · Classes" with the unmet part in red, the rarity and
-- upgrade in small type), then its main value, the statistics in small type in fixed groups, the trait, the skill
-- effects, the description and the value line ("Value: X gold") with the context price. Owner 2026-10-31 (replaces the
-- S134g second panel with the worn item): with ctx.compare the tooltip writes the change against what the equip takes
-- off right after each number it shows (green "(+2)", red "(-2)", grey "(=)"), and every base stat or line only the worn
-- item has comes as a red "lost" row ("-5 Siły") in its group; "Replaces: <name>" and the two-hander note stay.
--
-- ctx (every field optional):
--   lang: string           -- "pl" | "en" (default: Locale's current language)
--   level: number          -- character level (the level in the head line turns red when higher; nil = met)
--   class: string          -- character class id (classes in the head line; effects of another class say so)
--   equipped: ItemInstance -- the equipped item it would replace ("Replaces: <name>")
--   compare: {ItemInstance} -- 2026-10-31: what equipping it takes off (Logic/ItemCompare.replaced): the changes
--   shop: Shops.ShopDef    -- shop the item is offered in
--   shopEntry: Shops.Entry -- the offered entry: adds "Price: X gold" (ShopPrice.unit, the same as the row)
--   potionDiscount: number -- guild potion discount (derived stat), for the shop price
--   merchantOpen: boolean  -- a merchant window is open: backpack items add "Sells for: X gold"
--   hints: boolean         -- false hides the "double click: equip/use" hint (default: shown outside shops)
--   pathId: string         -- S68: the main path; S138: the leading direction (Logic/Paths.mainOf)
--   nodes: {[id]: number}  -- S68: character.path.nodes (owned nodes are marked in trait details)
--   mainHand: ItemInstance -- S68: equipped weapon (Full Draw details; an off-hand against a two-hander)
--   offhand: ItemInstance  -- S68: equipped off-hand (a two-handed candidate also replaces it)
--   input: "mouse"|"touch" -- S68: picks the details hint; nil = no hint (tests, admin dump)
--   detailsKey: string     -- S68: label of the details key on PC (Keybinds.label("item_details"))
--   view: "compact"|"full" -- 2026-10-21: "compact" = the short tooltip (TooltipModel.compactOf); nil = the full one
--
-- 2026-10-21 (owner: descriptions too long, the game unreadable): the item tooltip opens compact (name, head, rarity,
-- the main value in one line, at most COMPACT_STATS + 1 stat rows, the trait in one line, the skill effects by name in
-- one line (2026-10-31; what they do is in the full view), a price
-- only in a shop or at a merchant, the "Alt: details" / "More ▸" line). Holding the details key (PC) or "More ▸"
-- (touch) shows the full tooltip below; the compact one only leaves lines out, every one stays in the full view.
--
-- Line fields: `text` (may hold rich text), `role` (what the line is, for tests and the admin dump), `tone`
-- (colour role), `hex` (explicit colour, overrides tone), `size`, `font`; bonus rows have `kind = "bonus"`,
-- `quality` 0..1, `tier` (Data/Bonuses) and `legendary` / `mythic` from it. S62: weapons and off-hands get a "Trait"
-- section (name + line, Data/ItemTraits colour), only for live traits. S134g roles: `head`, `rarity`, `speedDps`,
-- `gap` (a thin space between stat groups), `fxTitle` / `fx` / `fxClass` (skill effects), `replaces`, `compareNote`;
-- 2026-10-31: `lost` (a stat or line of the worn item this one lacks, red, among the statistics).
-- Every bonus, trait and effect row carries a `detail` reference that `TooltipModel.details` turns into the details
-- panel (S68).

local Binding = require("./Binding")
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
local ItemCompare = require("./ItemCompare")
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
local Reroll = require("./Reroll")
local ShopPrice = require("./ShopPrice")
local Shops = require("../Data/Shops")
local SkillData = require("../Data/Skills")
local StatGroups = require("./StatGroups")
local TeleportStone = require("./TeleportStone")
local Stats = require("../Data/Stats")
local Traits = require("./Traits")
local Transmog = require("./Transmog")
local Types = require("../Types")
local UiPalette = require("../Data/UiPalette")
local Upgrade = require("./Upgrade")

type ItemInstance = Types.ItemInstance
type ItemDef = Items.ItemDef

export type Tone = "dark" | "muted" | "good" | "bad" | "rarity" | "bonus" | "legendary" | "trait"
export type Tier = "regular" | "legendary" | "mythic"

-- S68: what a row's details panel describes (a bonus line of this item, or the item's trait).
-- S134g: or a skill effect of the item (Data/ItemEffects id).
export type DetailRef =
	{ kind: "bonus", id: string, v: number, quality: number?, rerolled: boolean? }
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
	rerolled: boolean?, -- S134j: the item's locked reroll line (ItemTooltip adds TooltipModel.REROLL_MARK)
	main: boolean?, -- 2026-10-21: the main value (damage, magic damage, armour), not a grouped statistic
}

export type Ctx = {
	lang: string?,
	level: number?,
	class: string?,
	equipped: ItemInstance?,
	compare: { ItemInstance }?,
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
	view: ("compact" | "full")?,
	now: number?, -- owner 2026-11-01: server time (os.time seconds) for the rest of an everlasting stone
}

export type Model = { lines: { Line } }

local TooltipModel = {}

-- S134j: the mark of the locked reroll line (tooltip row, the smith's Transmute tab, the admin dump).
TooltipModel.REROLL_MARK = "↻"

-- S68 (STATY 11): the order of the line tiers (S134g: rows sort by STAT_GROUPS; the tier styles legacy lines).
TooltipModel.TIER_ORDER = table.freeze({ regular = 1, legendary = 2, mythic = 3 })

-- Formatting ----------------------------------------------------------------------------------------------

local ALIASES: { [string]: string } = StatGroups.ALIASES

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

-- S134j: the text of a line (the smith's Transmute tab draws the same rows as the tooltip).
function TooltipModel.bonusText(lang: string, id: string, value: number): string
	return bonusText(lang, id, value)
end

-- S134j: a line (or a pool marker "@vsFamily": its variants' text) with a value range ("+3–7 Siły").
function TooltipModel.rangeText(lang: string, id: string, low: number, high: number): string
	local marker = Bonuses.isParam(id)
	local def = Bonuses.get(if marker then Bonuses.variants(id)[1] or id else id)
	local places = if def then def.decimals else 0
	local function f(value: number): string
		return if places == 0 then tostring(math.floor(value + 0.5)) else decimal(value, places, lang)
	end
	local key = if marker then `bonusParam.{string.sub(id, 2)}` else `bonus.{id}`
	return Locale.T(key, { v = Locale.T("smith.reroll.range", { min = f(low), max = f(high) }, lang) }, lang)
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

-- Comparison (owner 2026-10-31) ------------------------------------------------------------------------------

-- Colours of the change next to a value: parchment roles, ItemTooltip draws each in the iron role of the same name.
TooltipModel.DELTA_HEX = table.freeze({
	good = UiPalette.paper.success,
	bad = UiPalette.paper.danger,
	same = UiPalette.paper.textMuted,
})

-- 2026-10-31 (Studio check): an item of another class than the viewer's (ctx.class) is compared with nothing: no
-- changes, no "Replaces", no two-hander note. A too high level is red in the head line and still compared.
local function classFits(d: ItemDef, c: Ctx): boolean
	return c.class == nil or d.classes == nil or table.find(d.classes, c.class) ~= nil
end

-- What the tooltip compares with (ctx.compare summed, Logic/ItemCompare); nil without a comparison, for items that are
-- neither equipment nor a backpack, of another class, and for an item compared with itself.
local function wornOf(item: ItemInstance, d: ItemDef, c: Ctx): ItemCompare.Worn?
	local list = c.compare
	if not list or #list == 0 or (d.category ~= "equipment" and d.category ~= "backpack") or not classFits(d, c) then
		return nil
	end
	for _, other in list do
		if other.uid == item.uid then
			return nil
		end
	end
	return ItemCompare.worn(list)
end

-- " (+2)" green, " (-2)" red or " (=)" grey after a value: `value` against `worn`, both written with `places` decimals;
-- `write` writes the size of the change the way the value is written (decimals, "%"). A change too small to show is "=".
local function changeText(value: number, worn: number, places: number, write: (number) -> string): string
	local change = ItemCompare.change(value, worn, places)
	local size = write(math.abs(change))
	if change == 0 or string.find(size, "[1-9]") == nil then
		return ` <font color="{TooltipModel.DELTA_HEX.same}">(=)</font>`
	end
	local hex = if change > 0 then TooltipModel.DELTA_HEX.good else TooltipModel.DELTA_HEX.bad
	return ` <font color="{hex}">({if change > 0 then "+" else "-"}{size})</font>`
end

local function wholeNumber(value: number): string
	return tostring(math.floor(value + 0.5))
end

-- A line's number the way its text writes it ("5", "2,5", "4%").
local function lineNumber(id: string, value: number, lang: string): string
	local def = Bonuses.get(id)
	local places = if def then def.decimals else 0
	local text = if places == 0 then wholeNumber(value) else decimal(value, places, lang)
	return if def and def.percent then text .. "%" else text
end

local function lineChange(id: string, value: number, worn: number, lang: string): string
	local def = Bonuses.get(id)
	return changeText(value, worn, if def then def.decimals else 0, function(n: number): string
		return lineNumber(id, n, lang)
	end)
end

-- Base statistics are whole or have one decimal (ItemRoll.itemStats), written by formatStat.
local function statChange(key: string, value: number, worn: number, lang: string): string
	return changeText(value, worn, 1, function(n: number): string
		return formatStat(key, n, lang)
	end)
end

-- A line only the worn item has, written as the loss: "+{v} Siły" -> "-5 Siły", "Przebicie pancerza {v}%" -> "...
-- -3%", a reduction "-{v}% kosztu" -> "+4% kosztu" (losing it costs that much).
local LOST_MARK = "\1"
local function lostLineText(lang: string, id: string, value: number): string
	local def = Bonuses.get(id)
	local places = if def then def.decimals else 0
	local v = if places == 0 then wholeNumber(value) else decimal(value, places, lang)
	local text = Locale.T(`bonus.{id}`, { v = LOST_MARK }, lang)
	text = (string.gsub(text, "%+" .. LOST_MARK, function(): string
		return "-" .. v
	end))
	text = (string.gsub(text, "%-" .. LOST_MARK, function(): string
		return "+" .. v
	end))
	text = (string.gsub(text, LOST_MARK, function(): string
		return "-" .. v
	end))
	return text
end

-- The weapon's damage parts ("Damage 191 (+12)", "Magic damage 40 (=)"), each with its change; a kind of damage only
-- the worn weapon deals is a lost part ("Damage -30").
type DamagePart = { text: string, lost: boolean }
local function damageParts(w: { dmg: number, mdmg: number }, worn: ItemCompare.Worn?, lang: string): { DamagePart }
	local was = if worn then worn.weapon else nil
	local parts: { DamagePart } = {}
	for _, kind in { { key = "dmg", text = "tooltip.damage" }, { key = "mdmg", text = "tooltip.magicDamage" } } do
		local value: number = (w :: any)[kind.key]
		local old: number = if was then (was :: any)[kind.key] else 0
		if value > 0 then
			local text = Locale.T(kind.text, { [kind.key] = value }, lang)
			if was then
				text ..= changeText(value, old, 0, wholeNumber)
			end
			table.insert(parts, { text = text, lost = false })
		elseif old > 0 then
			table.insert(parts, { text = Locale.T(kind.text, { [kind.key] = -old }, lang), lost = true })
		end
	end
	return parts
end

-- " (+0,10)" after the attack speed and " (+12,5)" after the DPS, or "" without a worn weapon.
local function speedChange(w: { speed: number }, worn: ItemCompare.Worn?, lang: string): string
	local was = if worn then worn.weapon else nil
	if not was then
		return ""
	end
	return changeText(w.speed, was.speed, 2, function(n: number): string
		return decimal(n, 2, lang)
	end)
end

local function dpsChange(dps: number, worn: ItemCompare.Worn?, lang: string): string
	local was = if worn then worn.weapon else nil
	if not was then
		return ""
	end
	-- both rounded to the one decimal the tooltip writes, so the change matches the two numbers on screen
	local function one(value: number): number
		return math.floor(value * 10 + 0.5) / 10
	end
	return changeText(one(dps), one(was.dps), 1, function(n: number): string
		return decimal(n, 1, lang)
	end)
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

-- S134g (F1): the fixed groups of the statistics block (S134j: moved to Logic/StatGroups, shared with Logic/Reroll).
TooltipModel.STAT_GROUPS = StatGroups.LIST

-- S134g: (group index, place in the group) of a line id or base key; nil when no group lists it.
TooltipModel.groupOf = StatGroups.groupOf

-- The main value of a non-weapon item: its armour; everything else goes to the grouped statistics.
local MAIN_BASE = "armor"

-- Equipment main block: element, then weapon damage with speed and DPS in one line, or the armour of the base (FIX
-- 2026-10-15: the item level is in the footer; S134g: the grip, level and classes are in the head line).
-- 2026-10-31: with `worn` every number carries its change (a damage kind only the worn weapon deals: a red part).
local function mainValue(
	b: Builder,
	item: ItemInstance,
	stats: ItemRoll.ItemStats,
	lang: string,
	worn: ItemCompare.Worn?
)
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
		for _, part in damageParts(w, worn, lang) do
			b.add("stat", part.text, if part.lost then "bad" else "dark", { size = "body", font = "bold", main = true })
		end
		local dpsValue = TooltipModel.dps(w)
		local speed = Locale.T("tooltip.speed", { speed = decimal(w.speed, 2, lang) }, lang)
			.. speedChange(w, worn, lang)
		local dps = Locale.T("tooltip.dps", { dps = decimal(dpsValue, 1, lang) }, lang)
			.. dpsChange(dpsValue, worn, lang)
		b.add("speedDps", `{speed} · {dps}`, "dark")
	elseif stats.base[MAIN_BASE] then
		local value = stats.base[MAIN_BASE]
		local text = `{statName(lang, MAIN_BASE)}: <b>{formatStat(MAIN_BASE, value, lang)}</b>`
		if worn then
			text ..= statChange(MAIN_BASE, value, worn.base[MAIN_BASE] or 0, lang)
		end
		b.add("stat", text, "dark", { size = "body", main = true })
	end
end

local function tierOf(id: string): Tier
	local def = Bonuses.get(id)
	return if def then def.tier else "regular"
end

-- S134g (F1): the statistics in small type, in the fixed groups (TooltipModel.STAT_GROUPS) with a thin gap between
-- groups: the base stats besides the main value, then every line of the item (in a group the list's order, never the
-- roll's; a base stat before a line of the same stat). The quality bar stays on the lines; the rarity bonus last.
-- 2026-10-31: with `worn` each row ends with its change (a line against the worn line of the same id, the n-th against
-- the n-th), and what only the worn items have comes as red `lost` rows in its group after this item's rows.
local function groupedStats(
	b: Builder,
	item: ItemInstance,
	stats: ItemRoll.ItemStats,
	lang: string,
	worn: ItemCompare.Worn?
)
	type Row = { group: number, place: number, base: boolean, index: number, line: Line }
	local rows: { Row } = {}
	local others = #TooltipModel.STAT_GROUPS + 1
	-- S134j: the locked reroll line (rolled items only; named boss items never reroll)
	local itemDef = Items.get(item.id)
	local rerolledAt = if itemDef and itemDef.fixedBonuses == nil then Reroll.state(item).line else nil
	local keys: { string } = {}
	for stat in stats.base do
		if stats.weapon ~= nil or stat ~= MAIN_BASE then
			table.insert(keys, stat)
		end
	end
	table.sort(keys)
	for index, stat in keys do
		local group, place = TooltipModel.groupOf(stat)
		local text = `{statName(lang, stat)}: <b>{formatStat(stat, stats.base[stat], lang)}</b>`
		if worn then
			text ..= statChange(stat, stats.base[stat], worn.base[stat] or 0, lang)
		end
		table.insert(rows, {
			group = group or others,
			place = place or 0,
			base = true,
			index = index,
			line = {
				kind = "text",
				role = "stat",
				text = text,
				tone = "dark",
				size = "small",
			},
		})
	end
	local seen: { [string]: number } = {}
	for index, bonus in stats.bonuses do
		local group, place = TooltipModel.groupOf(bonus.id)
		local tier: Tier = tierOf(bonus.id)
		local rerolled = rerolledAt ~= nil and bonus.at == rerolledAt
		local text = bonusText(lang, bonus.id, bonus.v)
		if worn then
			local n = (seen[bonus.id] or 0) + 1
			seen[bonus.id] = n
			local list = worn.lines[bonus.id]
			text ..= lineChange(bonus.id, bonus.v, if list then list[n] or 0 else 0, lang)
		end
		table.insert(rows, {
			group = group or others,
			place = place or 0,
			base = false,
			index = index,
			line = {
				kind = "bonus",
				role = "bonus",
				text = text,
				tone = "bonus",
				size = "small",
				quality = bonus.quality,
				legendary = tier == "legendary",
				mythic = tier == "mythic",
				tier = tier,
				detail = {
					kind = "bonus",
					id = bonus.id,
					v = bonus.v,
					quality = bonus.quality,
					rerolled = if rerolled then true else nil,
				} :: DetailRef,
				rerolled = if rerolled then true else nil,
			},
		})
	end
	if worn then
		-- what only the worn items have: their base stats (sorted) and lines (in their order), as the loss
		local lost: { string } = {}
		for stat in worn.base do
			if stats.base[stat] == nil then
				table.insert(lost, stat)
			end
		end
		table.sort(lost)
		for index, stat in lost do
			local group, place = TooltipModel.groupOf(stat)
			table.insert(rows, {
				group = group or others,
				place = place or 0,
				base = true,
				index = #keys + index,
				line = {
					kind = "text",
					role = "lost",
					text = `{statName(lang, stat)}: <b>-{formatStat(stat, worn.base[stat], lang)}</b>`,
					tone = "bad",
					size = "small",
				},
			})
		end
		local index = #stats.bonuses
		for _, id in worn.lineOrder do
			local list = worn.lines[id]
			for n = (seen[id] or 0) + 1, #list do
				local group, place = TooltipModel.groupOf(id)
				index += 1
				table.insert(rows, {
					group = group or others,
					place = place or 0,
					base = false,
					index = index,
					line = {
						kind = "text",
						role = "lost",
						text = lostLineText(lang, id, list[n]),
						tone = "bad",
						size = "small",
					},
				})
			end
		end
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
-- effect's line; an effect of another class than the viewer's says whom it works for. S137 (DESIGN-18 §0.9): an effect
-- on a skill of one weapon pool (SkillDef.pool other than "common") names that pool: it works only with its weapon.
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
		local skill = SkillData.get(effect.skill)
		local pool = skill and skill.pool
		if pool and pool ~= "common" then
			b.add(
				"fxPool",
				Locale.T("tooltip.fx.pool", { pool = Locale.T(`skills.pool.{pool}`, nil, lang) }, lang),
				"muted",
				{ size = "small" }
			)
		end
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

-- S134g (F2, owner 2026-10-15): that an off-hand cannot go next to a two-hander (red) and what the item would replace
-- ("Replaces: <name>", a two-hander also the off-hand). 2026-10-31: the numbers of the comparison stand next to the
-- values above (ctx.compare); this line says what they are compared with.
local function replaceNotes(b: Builder, item: ItemInstance, d: ItemDef, c: Ctx, lang: string)
	local equipped = c.equipped
	if (equipped and equipped.uid == item.uid) or not classFits(d, c) then
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

-- The full tooltip of `item` (def defaults to Items.get(item.id)). S134g (F1, docs/DESIGN.md §23): name, head
-- ("Kind · Category · Level N · Classes"), rarity (small), the main value, the statistics in small type in fixed
-- groups, the rarity bonus, the trait, the skill effects, the description, the replace notes, binding, stack, item
-- level, value / price, the details hint and the action hint. Every category has the same first three lines.
local function buildFull(item: ItemInstance, def: ItemDef?, c: Ctx, lang: string): Model
	local b = builder()
	local itemDef = def or Items.get(item.id)
	if not itemDef then
		b.add("name", Locale.T("item.unknown", nil, lang))
		return { lines = b.lines }
	end
	local d = itemDef :: ItemDef
	local worn = wornOf(item, d, c) -- 2026-10-31: the changes against what the equip takes off

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
		mainValue(b, item, stats, lang, worn)
		groupedStats(b, item, stats, lang, worn)
		traitLines(b, stats, lang)
		effectLines(b, item, c, lang)
	elseif d.category == "backpack" then
		local capacity = d.capacity or 0
		local text = Locale.T("tooltip.capacity", { capacity = capacity }, lang)
		if worn and worn.capacity then
			text ..= changeText(capacity, worn.capacity, 0, wholeNumber)
		end
		b.add("effect", text, "dark", { font = "bold" })
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

	-- Binding (owner 2026-10-31, Logic/Binding): one short line, "bound" or "binds when equipped"; nothing for what
	-- trades freely (potions, materials, backpacks). Bound stacks too (S122: the Elixir of Wholeness).
	-- (owner 2026-11-01, Logic/TeleportStone) an everlasting stone: the place it is set to (a map or a boss dungeon), the
	-- rest left at `c.now` (without it, os.time); both stay in the compact view
	local placeKey = item.at and TeleportStone.placeKey(d, item.at)
	if placeKey then
		b.add("stoneAt", Locale.T("tooltip.stoneAt", { map = Locale.T(placeKey, nil, lang) }, lang), "muted")
	end
	local restMinutes = TeleportStone.minutesLeft(item, c.now or os.time())
	if restMinutes > 0 then
		b.add("stoneRest", Locale.T("tooltip.stoneRest", { minutes = restMinutes }, lang), "bad")
	end
	local bindKey = Binding.tooltipKey(item, d)
	if bindKey then
		b.add("bind", Locale.T(bindKey, nil, lang), if bindKey == "tooltip.bound" then "bad" else "muted")
	end
	if item.n > 1 then
		b.add("stack", Locale.T("tooltip.stack", { n = item.n }, lang), "muted")
	end
	-- FIX 2026-10-15: the item level is a detail (the requirement above says what matters): footer, small.
	if d.category == "equipment" then
		local ilvl = Locale.T("tooltip.ilvl", { ilvl = item.ilvl }, lang)
		if worn then
			ilvl ..= changeText(item.ilvl, worn.ilvl, 0, wholeNumber)
		end
		b.add("ilvl", ilvl, "muted", { size = "small" })
		-- S134j: how many times the item was rerolled at the smith (the cost of the next one grows with it)
		local rerolls = Reroll.state(item).n
		if rerolls > 0 then
			b.add("rerollCount", Locale.T("tooltip.reroll.count", { n = rerolls }, lang), "muted", { size = "small" })
		end
		-- S154: the worn look (Logic/Transmog); the name and every line above stay the item's own
		local look = Transmog.current(item)
		local lookDef = if look then Transmog.lookDef(look) else nil
		if lookDef then
			b.add(
				"transmog",
				Locale.T("tooltip.transmog", { name = ItemName.get(lang, lookDef.id) }, lang),
				"muted",
				{ size = "small" }
			)
		end
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
			-- 2026-10-21: on PC the full view shows while the details key is held, so the hint only says to point
			local text = if c.input == "touch"
				then Locale.T("tooltip.detailsHint.touch", nil, lang)
				else Locale.T("tooltip.detailsHint.mouse", nil, lang)
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

-- Compact view (2026-10-21) --------------------------------------------------------------------------------------

-- The most lines of a compact tooltip (tests/tooltip.spec: every legendary item with the hint line; a mythic one with
-- two effects may need one more): the stat rows (base statistics and lines) get what the other lines leave, at least
-- COMPACT_MIN_STATS of them are shown; rows over the budget become "+N more".
TooltipModel.COMPACT_MAX_LINES = 10
TooltipModel.COMPACT_MIN_STATS = 2
-- Material uses shown before "+N more".
TooltipModel.COMPACT_USES = 2

-- Roles of the full tooltip the compact one keeps as they are.
local COMPACT_KEEP: { [string]: boolean } = {
	name = true,
	head = true,
	rarity = true,
	effect = true, -- what a potion, elixir, blessing, stone, tool or backpack does
	duration = true,
	usedFor = true,
	compareNote = true, -- red: an off-hand next to a two-hander
	price = true, -- shop price
	sellFor = true, -- a merchant is open
	stoneAt = true, -- owner 2026-11-01: the place an everlasting stone is set to
	stoneRest = true, -- and the minutes it still rests
}

-- Roles folded into one compact line (mainShort, traitShort, fxShort) or counted in "+N more".
local STAT_ROLES: { [string]: boolean } = { stat = true, bonus = true, gap = true, lost = true }
-- The skill effect lines of the full view (folded into one compact line of names).
local STAT_FX: { [string]: boolean } = { fxTitle = true, fx = true, fxPool = true, fxClass = true }

local function moreLine(b: Builder, n: number, lang: string)
	b.add("more", Locale.T("tooltip.compact.more", { n = n }, lang), "muted", { size = "small" })
end

-- The compact tooltip made from the full one (`full` = buildFull's lines): it keeps COMPACT_KEEP, folds the weapon's
-- main value and the trait into one line each and the skill effects into one line of names, cuts the stat rows to the
-- line budget and the material
-- uses, and ends with the details hint when the caller says the input ("moreHint"). Every line it leaves out stays in
-- the full view.
function TooltipModel.compactOf(full: { Line }, item: ItemInstance, c: Ctx, lang: string): { Line }
	local b = builder()
	local hidden = false
	local mainDone = false
	local statRows: { Line } = {}
	local statsAt: number? = nil
	local itemDef = Items.get(item.id)
	local worn = if itemDef then wornOf(item, itemDef, c) else nil
	local i = 1
	while i <= #full do
		local line = full[i]
		local role = line.role
		-- "cannot be sold" only matters at a merchant or in a shop (red)
		if COMPACT_KEEP[role] or (role == "noSell" and (c.merchantOpen or c.shopEntry ~= nil)) then
			table.insert(b.lines, line)
		elseif role == "bind" then
			-- owner 2026-10-31: bound / binds when equipped joins the rarity line ("Heroiczny · +3 · Wiąże się po
			-- założeniu"), so the short view keeps its line count
			local merged = false
			for n = #b.lines, 1, -1 do
				if b.lines[n].role == "rarity" then
					local copy = table.clone(b.lines[n])
					copy.text ..= ` · {line.text}`
					b.lines[n] = copy
					merged = true
					break
				end
			end
			if not merged then
				table.insert(b.lines, line)
			end
		elseif line.main or role == "speedDps" then
			-- weapon: "Damage 191 · DPS 229.2" in one line (2026-10-31: with the changes); armour: its line as it is
			local weapon = ItemRoll.itemStats(item).weapon
			if not weapon then
				table.insert(b.lines, line)
			elseif not mainDone then
				local parts: { string } = {}
				for _, part in damageParts(weapon, worn, lang) do
					table.insert(
						parts,
						if part.lost then `<font color="{TooltipModel.DELTA_HEX.bad}">{part.text}</font>` else part.text
					)
				end
				local dps = TooltipModel.dps(weapon)
				table.insert(
					parts,
					Locale.T("tooltip.compact.dps", { dps = decimal(dps, 1, lang) }, lang) .. dpsChange(dps, worn, lang)
				)
				b.add("mainShort", table.concat(parts, " · "), "dark", { size = "body", font = "bold" })
			end
			mainDone = true
			hidden = hidden or role == "speedDps"
		elseif STAT_ROLES[role] then
			-- the grouped statistics are one block, cut to the budget below (the place is kept)
			while i <= #full and STAT_ROLES[full[i].role] and not full[i].main do
				if full[i].role ~= "gap" then
					local copy = table.clone(full[i])
					copy.detail = nil -- the details panels belong to the full view
					table.insert(statRows, copy)
				end
				i += 1
			end
			i -= 1
			statsAt = #b.lines + 1
		elseif role == "traitName" then
			-- "◆ Fencing · 10%: counter after a blow"
			local ref = line.detail
			local def = if ref and ref.kind == "trait" then ItemTraits.get(ref.id) else nil
			local nextLine = full[i + 1]
			local text = if nextLine and nextLine.role == "trait" then nextLine.text else ""
			local name = if def then Locale.T(def.nameKey, nil, lang) else TooltipModel.plain(line.text)
			b.add(
				"traitShort",
				if text ~= "" then `{ItemTraits.ICON} <b>{name}</b> · {text}` else `{ItemTraits.ICON} <b>{name}</b>`,
				"trait",
				{ hex = ItemTraits.COLOR }
			)
			if nextLine and nextLine.role == "trait" then
				i += 1
			end
			hidden = true
		elseif role == "fxTitle" then
			-- 2026-10-31 (Studio check: a mythic tooltip ran past 14 lines): every skill effect in one line, by name in
			-- its tier's colour ("Lodowe Odpryski · Lodowy Wir"), another class's muted with "(works for: Mage)"; what
			-- each does is in the full view (Alt / "More ▸")
			local parts: { string } = {}
			local tier: Tier? = nil
			while i <= #full and STAT_FX[full[i].role] do
				local title = full[i]
				if title.role == "fxTitle" then
					local ref = title.detail
					local def = if ref and ref.kind == "effect" then ItemEffects.resolve(ref.id) else nil
					local name = if def then Locale.T(def.nameKey, nil, lang) else TooltipModel.plain(title.text)
					local hex = title.hex or Rarities.get(Rarities.LEGENDARY).textHex
					local other: string? = nil
					local j = i + 1
					while
						j <= #full and (full[j].role == "fx" or full[j].role == "fxPool" or full[j].role == "fxClass")
					do
						if full[j].role == "fxClass" then
							other = full[j].text
						end
						j += 1
					end
					i = j - 1
					table.insert(
						parts,
						if other
							then `<font color="{UiPalette.paper.textMuted}"><b>{name}</b> {other}</font>`
							else `<font color="{hex}"><b>{name}</b></font>`
					)
					tier = if title.tier == "mythic" or tier == "mythic" then "mythic" else title.tier :: Tier?
				end
				i += 1
			end
			i -= 1
			b.add("fxShort", table.concat(parts, " · "), "dark", { tier = tier })
			hidden = true
		elseif role == "use" then
			-- material uses: the first ones, the rest counted
			local uses: { Line } = {}
			while i <= #full and full[i].role == "use" do
				table.insert(uses, full[i])
				i += 1
			end
			i -= 1
			local shown = if #uses <= TooltipModel.COMPACT_USES + 1 then #uses else TooltipModel.COMPACT_USES
			for n = 1, shown do
				table.insert(b.lines, uses[n])
			end
			if shown < #uses then
				moreLine(b, #uses - shown, lang)
				hidden = true
			end
		elseif role ~= "detailsHint" then
			hidden = true
		end
		i += 1
	end
	-- the stat rows: as many as the other lines leave (the hint line counted), the rest "+N more"
	local at = statsAt
	if at then
		local others = #b.lines + (if c.input then 1 else 0)
		local budget = math.max(TooltipModel.COMPACT_MIN_STATS + 1, TooltipModel.COMPACT_MAX_LINES - others)
		local shown = if #statRows <= budget then #statRows else budget - 1
		local block: { Line } = table.move(statRows, 1, shown, 1, {})
		if shown < #statRows then
			table.insert(block, {
				kind = "text",
				role = "more",
				text = Locale.T("tooltip.compact.more", { n = #statRows - shown }, lang),
				tone = "muted",
				size = "small",
			})
			hidden = true
		end
		for n, line in block do
			table.insert(b.lines, at + n - 1, line)
		end
	end
	if hidden and c.input then
		local text = if c.input == "touch"
			then Locale.T("ui.details.more", nil, lang)
			else Locale.T("tooltip.more.mouse", { key = c.detailsKey or "Alt" }, lang)
		b.add("moreHint", text, if c.input == "touch" then "bonus" else "muted", { size = "small" })
	end
	return b.lines
end

-- Builds the tooltip lines of `item` (def defaults to Items.get(item.id)): the full view, or with ctx.view "compact"
-- the short one (TooltipModel.compactOf). ctx.view "full" on touch ends with "Less ▾" (role lessHint), the way back.
function TooltipModel.build(item: ItemInstance, def: ItemDef?, ctx: Ctx?): Model
	local c: Ctx = ctx or {}
	local lang = c.lang or Locale.getLanguage()
	local model = buildFull(item, def, c, lang)
	if c.view == "compact" then
		return { lines = TooltipModel.compactOf(model.lines, item, c, lang) }
	end
	if c.view == "full" and c.input == "touch" and #model.lines > 3 then
		table.insert(model.lines, {
			kind = "text",
			role = "lessHint",
			text = Locale.T("ui.details.less", nil, lang),
			tone = "bonus",
			size = "small",
		})
	end
	return model
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
	local bonus = ref :: { kind: "bonus", id: string, v: number, quality: number?, rerolled: boolean? }
	local details = bonusDetails(item, bonus.id, bonus.v, bonus.quality, lang)
	if bonus.rerolled then
		-- S134j: the locked reroll line says where it changes
		table.insert(
			details.rows,
			{ role = "reroll", text = Locale.T("tooltip.details.reroll", nil, lang), tone = "muted" }
		)
	end
	return details
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
