--!strict
-- Item icons (S35): which atlas icon an item definition uses and the colour of each layer. Pure; the
-- client turns the result into stacked ImageLabels (UI/Components/ItemIcon). Rarity is never part of the
-- icon, only of the slot frame.
--   equipment       "eq/<type>", material layer tinted by TIER_TINT[def.tier]; named boss items "uniq/<id>"
--   mage weapons    accent layer = element colour of the instance (Elements.COLORS)
--   potions         "pot/<size 1-5>", elixirs "pot/elixir", accent = def.icon.color
--   blessings       "bless/<line>" (blessing_<line>_<n>)
--   ore, herb, fish "mat/ore" | "mat/herb" | "mat/fish", accent = def.icon.color; other materials "mat/<id>"
--   stone, scroll, backpack  "misc/<type>", accent = def.icon.color; tools "tool/<id>"

local Atlas = require("../Data/ItemIconAtlas")
local Elements = require("../Data/Elements")
local Items = require("../Data/Items")
local Sheets = require("../Data/ItemIconSheets")

type ItemDef = Items.ItemDef

export type Layer = {
	image: number, -- sheet number (ItemIcons.sheet(image) is the asset id)
	x: number, -- ImageRectOffset in the sheet; ImageRectSize is CELL x CELL
	y: number,
	tint: string?, -- hex colour multiplied into the layer (ImageColor3); nil = white
}
export type Resolved = { key: string, layers: { Layer } }

local ItemIcons = {}

ItemIcons.CELL = Atlas.CELL
ItemIcons.SHEETS = Atlas.SHEETS

local DATA_ACCENT_MATERIALS: { [string]: string } = { ore = "mat/ore", herb = "mat/herb", fish = "mat/fish" }
local DATA_ACCENT_MISC: { [string]: string } =
	{ stone = "misc/stone", scroll = "misc/scroll", backpack = "misc/backpack" }
-- Materials added after the atlas was drawn (S32 parts), shown with the drawn icon of the same thing.
local MATERIAL_ALIASES: { [string]: string } = { crow_feather = "mat/feather", toad_venom = "mat/venom_sac" }

-- Atlas key of a definition and whether the accent comes from def.icon.color.
function ItemIcons.keyOf(def: ItemDef): (string?, boolean)
	local kind = def.type
	if def.category == "equipment" then
		local named = `uniq/{def.id}`
		if Atlas.ICONS[named] then
			return named, false
		end
		return `eq/{kind}`, false
	elseif def.category == "consumable" then
		if string.sub(kind, 1, 7) == "potion_" then
			return `pot/{math.clamp(def.tier or 1, 1, 5)}`, true
		elseif kind == "elixir" then
			return "pot/elixir", true
		elseif kind == "blessing" then
			local line = string.match(def.id, "^blessing_(%a+)_")
			return if line then `bless/{line}` else nil, false
		end
		return nil, false
	elseif def.category == "material" then
		local shared = DATA_ACCENT_MATERIALS[kind]
		if shared then
			return shared, true
		end
		return MATERIAL_ALIASES[def.id] or `mat/{def.id}`, false
	elseif def.category == "tool" then
		return `tool/{def.id}`, false
	end
	local misc = DATA_ACCENT_MISC[def.category]
	if misc then
		return misc, true
	end
	return nil, false
end

-- Tint of the tier layer: the highest listed tier <= def.tier.
function ItemIcons.tierTint(tier: number?): string
	local best, bestTier = Atlas.TIER_TINT[1], 1
	for t, color in Atlas.TIER_TINT do
		if t <= (tier or 1) and t >= bestTier then
			best, bestTier = color, t
		end
	end
	return best
end

-- Layers of an item, bottom to top, or nil (no icon drawn yet: keep the glyph). `element` is the
-- instance element of mage weapons (ItemRoll.elementOf).
function ItemIcons.resolve(def: ItemDef, element: string?): Resolved?
	local key, dataAccent = ItemIcons.keyOf(def)
	local icon = if key then Atlas.ICONS[key] else nil
	if not key or not icon then
		return nil
	end
	local accent = if element and Elements.COLORS[element]
		then Elements.COLORS[element]
		elseif dataAccent then def.icon.color
		else icon.accent
	local tier = ItemIcons.tierTint(def.tier)
	local layers = {}
	for _, layer in icon.layers do
		table.insert(layers, {
			image = layer.s,
			x = layer.x,
			y = layer.y,
			tint = if layer.t == "tier" then tier elseif layer.t == "accent" then accent else nil,
		})
	end
	return { key = key, layers = layers }
end

-- Asset id of a sheet, or nil while it is not uploaded.
function ItemIcons.sheet(n: number): string?
	local id = Sheets[n]
	return if id and id ~= "" then id else nil
end

-- True when `ids` has an asset id ("rbxassetid://<digits>") for every sheet (S35, pure: tests pass their own list).
function ItemIcons.readyFor(ids: { string }): boolean
	for n = 1, Atlas.SHEETS do
		local id = ids[n]
		if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then
			return false
		end
	end
	return true
end

-- True when every sheet has an asset id (otherwise the UI keeps glyphs everywhere, never a half set).
function ItemIcons.ready(): boolean
	return ItemIcons.readyFor(Sheets :: any)
end

-- What the drag ghost (and other single icons) draw for an item instance: its definition, the element of a mage
-- weapon and the glyph with its colour for the time before the atlases are loaded. nil for unknown items.
function ItemIcons.visualOf(
	item: { id: string, el: string? }?
): { glyph: string, color: string, def: ItemDef, element: string? }?
	local def = if item then Items.get(item.id) else nil
	if not item or not def then
		return nil
	end
	local element = if def.elemental
		then (if Elements.isWeaponElement(item.el) then item.el else Elements.DEFAULT)
		else nil
	return { glyph = def.icon.glyph, color = def.icon.color, def = def, element = element }
end

-- Icon of a UI currency or other non-item picture ("ui/gold", "ui/exp", "ui/dragon").
function ItemIcons.named(key: string): Resolved?
	local icon = Atlas.ICONS[key]
	if not icon then
		return nil
	end
	local layers = {}
	for _, layer in icon.layers do
		local tint = if layer.t then icon.accent else nil
		table.insert(layers, { image = layer.s, x = layer.x, y = layer.y, tint = tint })
	end
	return { key = key, layers = layers }
end

return ItemIcons
