--!strict
-- Item looks (transmog, S154, docs/DESIGN.md §6b). Pure: the look of one item put on another of the same type at the
-- smith. Only the look changes: stats, type, rarity, level, lines, trait, effects, element and binding are the item's
-- (ItemScore, StatCalc, requirements and the weapon pool read the item, never `tm`).
--   types       the held types: every base type with a Part look in Data/WeaponLooks (weapons and off-hands). Armour
--               and jewellery are not drawn on the character yet (S132 class outfits); with armour layers they join
--               through the same rule.
--   look key    Transmog.lookOf(def): an item with its own model (WeaponLooks.assets[def.id], boss items) -> def.id;
--               else the tier model of Logic/ArtTiers ("<type>_<t>"); without any model "<type>" (one Part look per
--               type, not one per tier).
--   collection  account.transmog = { looks = { [key] = true }, scanned }: a look unlocks when an item with it enters
--               the backpack or the equipment (once scanned over every character), and stays after selling it.
--   item        `tm` = the look key worn (absent = its own look). Transmog.displayDef draws it; a key that no longer
--               exists or is of another type falls back to the item's own definition.
--   cost        Config.Transmog: gold on the upgrade gold curve x goldMul + essence by the item's rarity; taking a look
--               off (key "") is free.

local ArtTiers = require("./ArtTiers")
local Config = require("../Config")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Types = require("../Types")
local Upgrade = require("./Upgrade")
local WeaponLooks = require("../Data/WeaponLooks")

type ItemDef = Items.ItemDef
type ItemInstance = Types.ItemInstance

export type Cost = { gold: number, materials: { { id: string, n: number } } }
export type State = { looks: { [string]: boolean }, scanned: boolean }
-- The looks of one type: base looks (Part look / tier models, lowest first) and boss looks (by boss level).
export type TypeLooks = { type: string, base: { string }, boss: { string } }

local Transmog = {}

-- The mark of an item wearing another look (item slots; the reroll's ↻ is TooltipModel.REROLL_MARK).
Transmog.MARK = "↺"

-- Item fields a transmog never changes (everything but `tm`; tests/transmog.spec and tests/paywall.spec check them).
Transmog.KEEP = table.freeze({
	"uid",
	"id",
	"rarity",
	"ilvl",
	"bonuses",
	"up",
	"bound",
	"n",
	"locked",
	"el",
	"fx",
	"rv",
	"rr",
	"ns",
})

local TIERS: { number } = Items.bases.tiers

local function has(id: string): boolean
	return WeaponLooks.assets[id] ~= nil
end

-- Held types, in the order of the base list (weapons, then off-hands as Bases lists them).
local SLOTS: { string } = {}
local TYPE_SET: { [string]: boolean } = {}
for _, base in Items.bases.list do
	if WeaponLooks.get(base.type) ~= nil and (base.slot == "weapon" or base.slot == "offhand") then
		table.insert(SLOTS, base.type)
		TYPE_SET[base.type] = true
	end
end
Transmog.SLOTS = table.freeze(SLOTS)

function Transmog.supports(def: ItemDef?): boolean
	return def ~= nil and def.category == "equipment" and not def.stackable and TYPE_SET[def.type] == true
end

function Transmog.lookOf(def: ItemDef): string
	if has(def.id) then
		return def.id
	end
	return ArtTiers.modelId(def, has) or def.type
end

-- Every look that exists: key -> type and key -> the definition drawn and named for it.
local LOOK_TYPE: { [string]: string } = {}
local LOOK_DEF: { [string]: ItemDef } = {}
local BOSS: { [string]: boolean } = {}
for _, def in Items.byId do
	if Transmog.supports(def) then
		local key = Transmog.lookOf(def)
		LOOK_TYPE[key] = def.type
		if key == def.id then
			LOOK_DEF[key] = def
			if def.fixedBonuses ~= nil then
				BOSS[key] = true
			end
		elseif key == def.type then
			-- the Part look: named and drawn as the lowest tier of the type
			LOOK_DEF[key] = Items.get(`{def.type}_{TIERS[1]}`) or LOOK_DEF[key] or def
		else
			LOOK_DEF[key] = Items.get(key) or LOOK_DEF[key] or def
		end
	end
end

function Transmog.lookType(key: string): string?
	return LOOK_TYPE[key]
end

function Transmog.lookDef(key: string): ItemDef?
	return LOOK_DEF[key]
end

-- A look of a named boss item (rare: only from owning that item).
function Transmog.isBoss(key: string): boolean
	return BOSS[key] == true
end

-- The looks of every held type (the collection's catalogue), types in SLOTS order.
local CATALOGUE: { TypeLooks } = {}
do
	local byType: { [string]: TypeLooks } = {}
	for _, itemType in SLOTS do
		local entry: TypeLooks = { type = itemType, base = {}, boss = {} }
		byType[itemType] = entry
		table.insert(CATALOGUE, entry)
	end
	for key, itemType in LOOK_TYPE do
		local entry = byType[itemType]
		table.insert(if BOSS[key] then entry.boss else entry.base, key)
	end
	local function level(key: string): number
		local def = LOOK_DEF[key]
		return if def then def.tier or def.level else 0
	end
	for _, entry in CATALOGUE do
		for _, list in { entry.base, entry.boss } do
			table.sort(list, function(a: string, b: string): boolean
				local la, lb = level(a), level(b)
				if la ~= lb then
					return la < lb
				end
				return a < b
			end)
		end
	end
end

function Transmog.catalogue(): { TypeLooks }
	return CATALOGUE
end

-- The looks of one type (base then boss), or an empty list.
function Transmog.looksOf(itemType: string): { string }
	for _, entry in CATALOGUE do
		if entry.type == itemType then
			local out = table.clone(entry.base)
			table.move(entry.boss, 1, #entry.boss, #out + 1, out)
			return out
		end
	end
	return {}
end

-- Look keys of the held items in `items` (each once): what a scan or a new item unlocks.
function Transmog.unlocks(items: { ItemInstance }): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, item in items do
		local def = if type(item) == "table" then Items.get(item.id) else nil
		if def and Transmog.supports(def) then
			local key = Transmog.lookOf(def)
			if not seen[key] then
				seen[key] = true
				table.insert(out, key)
			end
		end
	end
	return out
end

-- The look the item wears now: its valid `tm`, or nil (its own look).
function Transmog.current(item: ItemInstance): string?
	local tm = item.tm
	if type(tm) ~= "string" then
		return nil
	end
	local def = Items.get(item.id)
	if not def or not Transmog.supports(def) or LOOK_TYPE[tm] ~= def.type or LOOK_DEF[tm] == nil then
		return nil
	end
	return tm
end

-- Whether `key` may be put on `item` ("" = take the look off: always allowed on a held item).
function Transmog.canApply(item: ItemInstance, key: string, looks: { [string]: boolean }?): (boolean, string?)
	local def = Items.get(item.id)
	if not def or not Transmog.supports(def) then
		return false, "transmog.error.type"
	end
	if key == "" then
		return true, nil
	end
	if LOOK_TYPE[key] == nil or not (looks and looks[key] == true) then
		return false, "transmog.error.locked"
	end
	if LOOK_TYPE[key] ~= def.type then
		return false, "transmog.error.mismatch"
	end
	if key == Transmog.lookOf(def) or key == Transmog.current(item) then
		return false, "transmog.error.same"
	end
	return true, nil
end

-- Gold and essence of putting a look on `item` (the item's level and rarity; taking it off costs nothing).
function Transmog.cost(item: ItemInstance): Cost
	local c = Config.Transmog
	local ilvl = math.max(1, math.floor(tonumber(item.ilvl) or 1))
	local gold = math.floor(ilvl * Upgrade.goldPerIlvl(ilvl) * c.goldMul + 0.5)
	local essence = (c.essence :: { [string]: { id: string, n: number } })[Rarities.get(item.rarity).key]
	local materials = if essence then { { id = essence.id, n = essence.n } } else {}
	return { gold = gold, materials = materials }
end

-- A copy of `item` wearing `key` ("" = its own look again); nothing else changes.
function Transmog.apply(item: ItemInstance, key: string): ItemInstance
	local copy = table.clone(item)
	copy.tm = if key == "" then nil else key
	return copy
end

-- The definition to draw (held model, icon) and to name as the look: the worn look, else the item's own.
function Transmog.displayDef(item: ItemInstance): ItemDef?
	local own = Items.get(item.id)
	local key = Transmog.current(item)
	if key then
		return LOOK_DEF[key] or own
	end
	return own
end

-- account.transmog read safely (no migration): only looks that exist, `scanned` false unless set.
function Transmog.sanitize(state: any): State
	local looks: { [string]: boolean } = {}
	local raw = if type(state) == "table" then state.looks else nil
	if type(raw) == "table" then
		for key, value in raw do
			if value == true and type(key) == "string" and LOOK_TYPE[key] ~= nil then
				looks[key] = true
			end
		end
	end
	return { looks = looks, scanned = type(state) == "table" and state.scanned == true }
end

-- "{n}/{all}" of one type's looks in `looks`.
function Transmog.count(itemType: string, looks: { [string]: boolean }): (number, number)
	local all = Transmog.looksOf(itemType)
	local n = 0
	for _, key in all do
		if looks[key] == true then
			n += 1
		end
	end
	return n, #all
end

return Transmog
