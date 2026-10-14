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
-- S52: pictures from art/icons/src (Atlas.PNG) come first when their sheets are ready: boss items "uniq/<id>",
-- equipment "eq/<type>@<tier>" of the nearest lower tier with a picture (Logic/ArtTiers), other items
-- "<group>/<item id>" (e.g. "mat/ore_copper"), then the picture of the shared key. Without a ready picture the icon
-- drawn by code (Atlas.ICONS) is used, so an atlas waiting for its upload never changes how the game looks.
-- S118: mage weapons use their picture too; a picture with an accent layer (`.a.png`) takes the element colour there,
-- one without gets `gem` (the element colour), drawn by the client as a small gem in the corner of the icon. Quest
-- objective items have pictures "quest/<item>" (ItemIcons.questItem). One item is always drawn whole from one source
-- (its picture, the code-drawn icon or the glyph); different items may be in different states (per sheet).

local ArtTiers = require("./ArtTiers")
local Atlas = require("../Data/ItemIconAtlas")
local Elements = require("../Data/Elements")
local Items = require("../Data/Items")
local Sheets = require("../Data/ItemIconSheets")

type ItemDef = Items.ItemDef
type Icon = Atlas.Icon

export type Layer = {
	image: number, -- sheet number (ItemIcons.sheet(image) is the asset id)
	x: number, -- ImageRectOffset in the sheet; ImageRectSize is CELL x CELL
	y: number,
	tint: string?, -- hex colour multiplied into the layer (ImageColor3); nil = white
}
export type Resolved = {
	key: string,
	layers: { Layer },
	picture: boolean?, -- S118: the owner's picture (Atlas.PNG), not the code-drawn icon
	gem: string?, -- S118: element colour of a mage weapon picture without an accent layer (client draws a gem)
}
-- Whether a sheet can be drawn (client: uploaded and loaded; default: it has an asset id).
export type Ready = (sheet: number) -> boolean
export type Candidate = { key: string, data: boolean }

local ItemIcons = {}

ItemIcons.CELL = Atlas.CELL
ItemIcons.SHEETS = Atlas.SHEETS
ItemIcons.SVG_SHEETS = Atlas.SVG_SHEETS

local DATA_ACCENT_MATERIALS: { [string]: string } = { ore = "mat/ore", herb = "mat/herb", fish = "mat/fish" }
local DATA_ACCENT_MISC: { [string]: string } =
	{ stone = "misc/stone", scroll = "misc/scroll", backpack = "misc/backpack" }
-- Materials added after the atlas was drawn (S32 parts), shown with the drawn icon of the same thing.
local MATERIAL_ALIASES: { [string]: string } = { crow_feather = "mat/feather", toad_venom = "mat/venom_sac" }

-- Code-drawn atlas key (Atlas.ICONS) of a definition and whether the accent comes from def.icon.color.
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

-- Atlas keys an item may use, best first (S52): pictures of the item or of its tier, then the shared key.
function ItemIcons.candidates(def: ItemDef): { Candidate }
	local base, dataAccent = ItemIcons.keyOf(def)
	local out: { Candidate } = {}
	if def.category == "equipment" then
		table.insert(out, { key = `uniq/{def.id}`, data = false })
		for _, key in ArtTiers.iconKeys(`eq/{def.type}`, def.tier) do
			table.insert(out, { key = key, data = false })
		end
	elseif base then
		local group = string.match(base, "^(%a+)/")
		local own = `{group}/{def.id}`
		if group and own ~= base then
			table.insert(out, { key = own, data = true })
		end
	end
	if base then
		table.insert(out, { key = base, data = dataAccent })
	end
	return out
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

-- Asset id of a sheet, or nil while it is not uploaded.
function ItemIcons.sheet(n: number): string?
	local id = Sheets[n]
	return if id and id ~= "" then id else nil
end

-- True when the sheet has an asset id (the readiness used outside the client: server, wiki export, tests).
function ItemIcons.hasId(n: number): boolean
	return ItemIcons.sheet(n) ~= nil
end

local function drawable(icon: Icon, ready: Ready): boolean
	for _, layer in icon.layers do
		if not ready(layer.s) then
			return false
		end
	end
	return true
end

local function hasAccent(icon: Icon): boolean
	for _, layer in icon.layers do
		if layer.t == "accent" then
			return true
		end
	end
	return false
end

-- Icon of an atlas key: the picture (Atlas.PNG) when all its sheets are ready, else the code-drawn icon when ready.
function ItemIcons.iconOf(key: string, ready: Ready?): Icon?
	local isReady: Ready = ready or ItemIcons.hasId
	local png = Atlas.PNG[key]
	if png and drawable(png, isReady) then
		return png
	end
	local svg = Atlas.ICONS[key]
	if svg and drawable(svg, isReady) then
		return svg
	end
	return nil
end

-- Key and icon an item shows now, and whether its accent comes from the data.
function ItemIcons.pick(def: ItemDef, ready: Ready?): (string?, Icon?, boolean)
	for _, c in ItemIcons.candidates(def) do
		local icon = ItemIcons.iconOf(c.key, ready)
		if icon then
			return c.key, icon, c.data
		end
	end
	return nil, nil, false
end

-- Layers of an item, bottom to top, or nil (no icon drawn yet: keep the glyph). `element` is the
-- instance element of mage weapons (ItemRoll.elementOf); `ready` says which sheets can be drawn.
function ItemIcons.resolve(def: ItemDef, element: string?, ready: Ready?): Resolved?
	local key, icon, dataAccent = ItemIcons.pick(def, ready)
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
	local picture = Atlas.PNG[key] == icon
	local gem = if picture
			and def.elemental
			and element
			and Elements.COLORS[element]
			and not hasAccent(icon)
		then Elements.COLORS[element]
		else nil
	return { key = key, layers = layers, picture = picture, gem = gem }
end

-- S118: picture of a quest objective item ("quest/<item>", the `item` of deliver / collect objectives), or nil
-- (no picture or its sheet not ready: the quest window shows only the text, as before).
function ItemIcons.questItem(item: string?, ready: Ready?): Resolved?
	if not item then
		return nil
	end
	local key = `quest/{item}`
	local icon = Atlas.PNG[key]
	if not icon or not drawable(icon, ready or ItemIcons.hasId) then
		return nil
	end
	local layers = {}
	for _, layer in icon.layers do
		table.insert(layers, { image = layer.s, x = layer.x, y = layer.y })
	end
	return { key = key, layers = layers, picture = true }
end

-- S118: the owner's pictures in numbers (/icons): items of the game, items whose icon is a picture (own or of a
-- lower tier) when every sheet is `ready` (default: has an asset id), that count per key group ("eq", "mat", ...),
-- quest items with a picture, picture sheets and those without an asset id (to upload).
export type Coverage = {
	items: number,
	withArt: number,
	byGroup: { [string]: number },
	questItems: number,
	sheets: number,
	waiting: { number },
}

function ItemIcons.coverage(ready: Ready?): Coverage
	local out: Coverage = { items = 0, withArt = 0, byGroup = {}, questItems = 0, sheets = 0, waiting = {} }
	for _, def in Items.byId do
		out.items += 1
		local r = ItemIcons.resolve(def, nil, ready)
		if r and r.picture then
			out.withArt += 1
			local group = string.match(r.key, "^(%a+)/") or "?"
			out.byGroup[group] = (out.byGroup[group] or 0) + 1
		end
	end
	for key in Atlas.PNG do
		if string.sub(key, 1, 6) == "quest/" then
			out.questItems += 1
		end
	end
	for n = Atlas.SVG_SHEETS + 1, Atlas.SHEETS do
		out.sheets += 1
		if not ItemIcons.sheet(n) then
			table.insert(out.waiting, n)
		end
	end
	return out
end

-- True when `ids` has an asset id ("rbxassetid://<digits>") for every code-drawn sheet 1..SVG_SHEETS (S35, pure:
-- tests pass their own list). Picture sheets (S52) are ready one by one and fall back to these.
function ItemIcons.readyFor(ids: { string }): boolean
	for n = 1, Atlas.SVG_SHEETS do
		local id = ids[n]
		if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then
			return false
		end
	end
	return true
end

-- True when every code-drawn sheet has an asset id (otherwise the UI keeps glyphs everywhere).
function ItemIcons.ready(): boolean
	return ItemIcons.readyFor(Sheets :: any)
end

-- Picture keys (Atlas.PNG) by group ("eq", "mat", ...), sorted, for /artcoverage.
function ItemIcons.pictures(): { [string]: { string } }
	local out: { [string]: { string } } = {}
	for key in Atlas.PNG do
		local group = string.match(key, "^(%a+)/") or "?"
		out[group] = out[group] or {}
		table.insert(out[group], key)
	end
	for _, list in out do
		table.sort(list)
	end
	return out
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
function ItemIcons.named(key: string, ready: Ready?): Resolved?
	local icon = ItemIcons.iconOf(key, ready)
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
