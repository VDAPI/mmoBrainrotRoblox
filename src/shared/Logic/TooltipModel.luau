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
--
-- Line fields: `text` (may hold rich text), `role` (what the line is, for tests and the admin dump), `tone`
-- (colour role), `hex` (explicit colour, overrides tone), `size`, `font`; bonus rows have `kind = "bonus"`,
-- `quality` 0..1 and `legendary`.

local Blessings = require("../Data/Blessings")
local Bonuses = require("../Data/Bonuses")
local Classes = require("../Data/Classes")
local Crafting = require("../Data/Crafting")
local Elements = require("../Data/Elements")
local Format = require("../Util/Format")
local GatherNodes = require("../Data/GatherNodes")
local ItemName = require("./ItemName")
local ItemRoll = require("./ItemRoll")
local ItemValue = require("./ItemValue")
local Items = require("../Data/Items")
local Locale = require("../Util/Locale")
local Quests = require("../Data/Quests")
local Rarities = require("../Data/Rarities")
local Recipes = require("../Data/Recipes")
local ShopPrice = require("./ShopPrice")
local Shops = require("../Data/Shops")
local Stats = require("../Data/Stats")
local Types = require("../Types")
local Upgrade = require("./Upgrade")

type ItemInstance = Types.ItemInstance
type ItemDef = Items.ItemDef

export type Tone = "dark" | "muted" | "good" | "bad" | "rarity" | "bonus" | "legendary"

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
}

export type Model = { lines: { Line } }

local TooltipModel = {}

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

local function equipmentLines(b: Builder, item: ItemInstance, lang: string)
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
	local stats = ItemRoll.itemStats(item)
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
	for _, bonus in stats.bonuses do
		local bonusDef = Bonuses.get(bonus.id)
		local mythic = string.sub(bonus.id, 1, 5) == "myth_"
		table.insert(b.lines, {
			kind = "bonus",
			role = "bonus",
			text = bonusText(lang, bonus.id, bonus.v),
			tone = "bonus",
			quality = bonus.quality,
			legendary = not mythic
				and (bonusDef ~= nil and bonusDef.hook ~= nil or string.sub(bonus.id, 1, 4) == "leg_"),
			mythic = mythic,
		})
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

local function compareLines(b: Builder, item: ItemInstance, equipped: ItemInstance, lang: string)
	if equipped.uid == item.uid then
		return
	end
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
		b.add("compareTitle", Locale.T("tooltip.compare", nil, lang), "muted")
		b.add("compare", table.concat(lines, "\n"))
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
		equipmentLines(b, item, lang)
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

	if c.equipped and d.slot and d.slot ~= "backpack" then
		compareLines(b, item, c.equipped, lang)
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
