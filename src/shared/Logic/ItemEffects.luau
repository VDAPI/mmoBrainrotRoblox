--!strict
-- S134g: skill effects of Legendary and Mythic items (Data/ItemEffects; docs/STATY.md 2C, 9, 12). Pure, runs in Lune.
-- Rolling (`roll`, in place of the old legendary / mythic lines), the effects of a character's equipment (`active`,
-- `mods`: the extra Logic/Skills.effective sources Logic/Paths.effectiveFor adds after the path nodes), item hooks,
-- text arguments, and the save migration (`migrateItem`: AccountSchema, Logic/Mail and AuctionService call the same
-- function, so an item gets the same effects wherever it is converted first: the seed is its uid).
-- Rules: an effect works only for its class; one effect id works once even from two items; a retired id is read as
-- its `replacedBy`; unknown ids are skipped (STATY 12).

local Bonuses = require("../Data/Bonuses")
local Classes = require("../Data/Classes")
local EffectData = require("../Data/ItemEffects")
local Elements = require("../Data/Elements")
local Items = require("../Data/Items")
local Locale = require("../Util/Locale")
local Rarities = require("../Data/Rarities")
local SkillPoolData = require("../Data/SkillPools")
local Rng = require("./Rng")
local SkillTypes = require("../Data/Skills/Types")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance
type ItemDef = Items.ItemDef
export type ItemEffectDef = EffectData.ItemEffectDef
export type Tier = EffectData.Tier

local ItemEffects = {}

-- Slots in the order `active` reads them (weapon first, jewellery last).
ItemEffects.SLOT_ORDER = table.freeze({
	"weapon",
	"offhand",
	"helmet",
	"armor",
	"gloves",
	"boots",
	"necklace",
	"ring1",
	"ring2",
	"talisman",
})

local TIER_RANK: { [string]: number } = { legendary = 1, mythic = 2 }

-- The live definition of an id: a retired effect is read as its successor (replacedBy chains, at most 8 steps).
function ItemEffects.resolve(id: any): ItemEffectDef?
	if type(id) ~= "string" then
		return nil
	end
	local def = EffectData.get(id)
	local steps = 0
	while def and def.replacedBy and steps < 8 do
		def = EffectData.get(def.replacedBy)
		steps += 1
	end
	return def
end

-- The skill pool of the class a weapon type belongs to (Data/SkillPools: the pool whose main hand lists it and names no
-- element), nil for an off-hand, armour, jewellery or a type no pool lists.
function ItemEffects.weaponPool(classId: string, weaponType: string?): string?
	if weaponType == nil then
		return nil
	end
	local pools: any = SkillPoolData.get(classId)
	if not pools then
		return nil
	end
	for _, pool in pools.pools do
		local req = pool.weapon
		if req and req.main and table.find(req.main, weaponType) and req.element == nil then
			return pool.id
		end
	end
	return nil
end

-- Effects a new item can roll: class and tier, not retired. A Mage weapon with an element prefers its element's pool
-- and the class's common skills (falls back to every effect of the class when that leaves none). Owner 2026-10-20: any
-- other weapon only rolls effects of its own pool (a bow never a crossbow's) and of the class's common skills
-- (`weaponType` = the item's base type). Data order.
function ItemEffects.pool(classId: string, tier: Tier, element: string?, weaponType: string?): { ItemEffectDef }
	local all: { ItemEffectDef } = {}
	for _, def in EffectData.list do
		if def.class == classId and def.tier == tier and def.replacedBy == nil then
			table.insert(all, def)
		end
	end
	local own = element or ItemEffects.weaponPool(classId, weaponType)
	if own == nil then
		return all
	end
	local preferred: { ItemEffectDef } = {}
	for _, def in all do
		if def.pool == own or def.pool == "common" then
			table.insert(preferred, def)
		end
	end
	return if #preferred > 0 then preferred else all
end

-- The class an item's effects roll for: `forClass` when the item fits it, else one of the item's classes, else (a
-- class-free item without a known class) any class. Uses the rng only when it has to pick.
local function classFor(def: ItemDef?, forClass: string?, rng: Rng.Rng): string
	local classes: { string }? = if def then def.classes else nil
	if classes and #classes > 0 then
		if forClass and table.find(classes, forClass) then
			return forClass
		end
		return rng:pick(classes)
	end
	if forClass and Classes.get(forClass) then
		return forClass
	end
	return rng:pick(Classes.order :: any) :: string
end

-- Element of a Mage weapon instance (fire before S18), nil for everything else (same rule as ItemRoll.elementOf).
local function elementOf(item: any, def: ItemDef?): string?
	if not def or not def.elemental then
		return nil
	end
	return if Elements.isWeaponElement(item.el) then item.el else Elements.DEFAULT
end

-- Draws `count` effects of `tier` not in `taken` (ids), without repeats; appends to `out`.
local function draw(
	out: { string },
	taken: { [string]: boolean },
	classId: string,
	tier: Tier,
	count: number,
	rng: Rng.Rng,
	element: string?,
	weaponType: string?
)
	if count <= 0 then
		return
	end
	local candidates: { string } = {}
	for _, def in ItemEffects.pool(classId, tier, element, weaponType) do
		if not taken[def.id] then
			table.insert(candidates, def.id)
		end
	end
	rng:shuffle(candidates)
	for i = 1, math.min(count, #candidates) do
		table.insert(out, candidates[i])
		taken[candidates[i]] = true
	end
end

-- Effects of a new item of `rarity`: Rarities.legendaryEffects from the legendary pool, then mythicEffects from the
-- mythic pool of one class (`forClass` when the item fits it, as the jewellery lines of S32). `element`: a Mage
-- weapon's element. Empty below Legendary or for a non-equipment definition.
function ItemEffects.roll(defId: string, rarity: number, rng: Rng.Rng, forClass: string?, element: string?): { string }
	local out: { string } = {}
	local def = Items.get(defId)
	local rarityDef = Rarities.get(rarity)
	if not def or def.category ~= "equipment" or rarityDef.legendaryEffects + rarityDef.mythicEffects <= 0 then
		return out
	end
	local classId = classFor(def, forClass, rng)
	local taken: { [string]: boolean } = {}
	local weaponType = if def.slot == "weapon" then def.type else nil
	draw(out, taken, classId, "legendary", rarityDef.legendaryEffects, rng, element, weaponType)
	draw(out, taken, classId, "mythic", rarityDef.mythicEffects, rng, element, weaponType)
	return out
end

-- Effect ids of an item: a named item's definition (`fx`, per class for a shared one: the class's list, or every
-- class's list when `classId` is not among them), else the saved `fx` (strings only). Not resolved.
function ItemEffects.idsOf(item: any, classId: string?): { string }
	local out: { string } = {}
	if type(item) ~= "table" then
		return out
	end
	local def = Items.get(item.id)
	local fixed: any = if def then def.fx else nil
	local source: any = item.fx
	if fixed ~= nil then
		if fixed[1] ~= nil or next(fixed) == nil then
			source = fixed
		elseif classId and fixed[classId] then
			source = fixed[classId]
		else
			local merged: { string } = {}
			for _, id in Classes.order do
				for _, fxId in fixed[id] or {} do
					table.insert(merged, fxId)
				end
			end
			source = merged
		end
	end
	if type(source) ~= "table" then
		return out
	end
	for _, id in ipairs(source) do
		if type(id) == "string" then
			table.insert(out, id)
		end
	end
	return out
end

-- Resolved effects of an item (unknown ids skipped, each live id once), in the item's order.
function ItemEffects.ofItem(item: any, classId: string?): { ItemEffectDef }
	local out: { ItemEffectDef } = {}
	local seen: { [string]: boolean } = {}
	for _, id in ItemEffects.idsOf(item, classId) do
		local def = ItemEffects.resolve(id)
		if def and not seen[def.id] then
			seen[def.id] = true
			table.insert(out, def)
		end
	end
	return out
end

-- Effects of the character's equipment that work for its class: every id once, slot order, legendary before mythic.
function ItemEffects.list(character: any): { ItemEffectDef }
	local out: { ItemEffectDef } = {}
	if type(character) ~= "table" or type(character.equipment) ~= "table" then
		return out
	end
	local classId = character.class
	local seen: { [string]: boolean } = {}
	local order: { [string]: number } = {}
	for _, slot in ItemEffects.SLOT_ORDER do
		for _, def in ItemEffects.ofItem(character.equipment[slot], classId) do
			if def.class == classId and not seen[def.id] then
				seen[def.id] = true
				table.insert(out, def)
				order[def.id] = #out
			end
		end
	end
	table.sort(out, function(a: ItemEffectDef, b: ItemEffectDef): boolean
		local ta, tb = TIER_RANK[a.tier] or 9, TIER_RANK[b.tier] or 9
		if ta ~= tb then
			return ta < tb
		end
		return order[a.id] < order[b.id]
	end)
	return out
end

-- The skill changes of the character's item effects by skill id (Logic/Skills.effective sources, after the nodes).
function ItemEffects.active(character: any): { [string]: { SkillTypes.Breakpoint } }
	local out: { [string]: { SkillTypes.Breakpoint } } = {}
	for _, def in ItemEffects.list(character) do
		local list = out[def.skill]
		if not list then
			list = {}
			out[def.skill] = list
		end
		table.insert(list, def.bp)
	end
	return out
end

-- The item effects of one skill for the character (empty when none).
function ItemEffects.mods(character: any, skillId: string): { SkillTypes.Breakpoint }
	local out: { SkillTypes.Breakpoint } = {}
	for _, def in ItemEffects.list(character) do
		if def.skill == skillId then
			table.insert(out, def.bp)
		end
	end
	return out
end

-- Hooks of an item's effects (`hook`), summed like trait hooks (ItemRoll.itemStats adds them to result.hooks).
-- Every class's effects count here: the class filter is the hook's reader (an effect of another class has none).
function ItemEffects.hooks(item: any, classId: string?): { [string]: number }
	local out: { [string]: number } = {}
	for _, def in ItemEffects.ofItem(item, classId) do
		local hook = def.hook
		if hook and (classId == nil or def.class == classId) then
			out[hook.id] = (out[hook.id] or 0) + hook.value
		end
	end
	return out
end

-- Text numbers ----------------------------------------------------------------------------------------------------

local function number(value: number, lang: string): string
	if value % 1 == 0 then
		return tostring(math.floor(value))
	end
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "") :: string
	return if lang == "pl" then (string.gsub(text, "%.", ",")) else text
end

local function collect(args: { [string]: string }, value: any, key: string, lang: string)
	if type(value) == "number" then
		args[key] = number(math.abs(value), lang)
	elseif type(value) == "table" then
		for field, inner in value do
			if type(field) == "string" then
				collect(args, inner, field, lang)
			end
		end
	end
end

-- Arguments of itemfx.<id>.line: {skill} (the skill's current name) and every number of `bp` under its field name
-- (echo.pct -> {pct}, add.radius -> {radius}, values.surgePower -> {surgePower}, execute -> {execute}).
function ItemEffects.lineArgs(def: ItemEffectDef, lang: string?): { [string]: string }
	local language = lang or Locale.getLanguage()
	local args: { [string]: string } = {}
	for key, value in def.bp :: any do
		collect(args, value, key, language)
	end
	if def.hook then
		args.hook = number(def.hook.value, language)
	end
	args.skill = Locale.T(`skill.{def.skill}.name`, nil, language)
	return args
end

-- The finished effect line in `lang`.
function ItemEffects.line(def: ItemEffectDef, lang: string?): string
	return Locale.T(def.lineKey, ItemEffects.lineArgs(def, lang) :: any, lang)
end

-- Save migration -----------------------------------------------------------------------------------------------------

-- Whether a line id is a legendary / mythic line (the old fourth to sixth lines).
local function isEdgeLine(stat: any): boolean
	if type(stat) ~= "string" then
		return false
	end
	local bonus = Bonuses.get(stat)
	return bonus ~= nil and bonus.tier ~= "regular"
end

-- S134g (C2): brings a Legendary / Mythic item to the effect rules. Removes the legendary and mythic lines, keeps the
-- regular lines and their values (no reroll), keeps the known effects and rolls the missing ones (Rarities
-- legendaryEffects + mythicEffects) with a seed from the uid, for `classHint` when the item fits it, else one of its
-- classes. Named items (definition lines) and everything below Legendary stay untouched. Idempotent; type-safe on
-- junk (a non-table bonuses list becomes empty). Mutates the item; true when it changed.
function ItemEffects.migrateItem(item: any, itemDef: ItemDef?, classHint: string?): boolean
	if type(item) ~= "table" or type(item.id) ~= "string" then
		return false
	end
	local def = itemDef or Items.get(item.id)
	if not def or def.category ~= "equipment" or def.fixedBonuses ~= nil then
		return false
	end
	local rarity = tonumber(item.rarity)
	if not rarity or rarity < Rarities.LEGENDARY then
		return false
	end
	local rarityDef = Rarities.get(rarity)
	local changed = false

	if type(item.bonuses) ~= "table" then
		item.bonuses = {}
		changed = true
	end
	local kept: { any } = {}
	for _, bonus in ipairs(item.bonuses) do
		if type(bonus) == "table" and isEdgeLine(bonus.stat) then
			changed = true
		else
			table.insert(kept, bonus)
		end
	end
	if changed then
		item.bonuses = kept
	end

	local ids: { string } = {}
	local taken: { [string]: boolean } = {}
	local have: { [string]: number } = { legendary = 0, mythic = 0 }
	local weaponType = if def.slot == "weapon" then def.type else nil
	local raw = item.fx
	if raw ~= nil and type(raw) ~= "table" then
		changed = true
	end
	if type(raw) == "table" then
		local count = 0
		for _ in raw do
			count += 1
		end
		for _, id in ipairs(raw) do
			local fxDef = ItemEffects.resolve(id)
			-- owner 2026-10-20: a weapon keeps only effects of its own pool (a bow lost its crossbow effects; redrawn)
			local own = if fxDef and weaponType then ItemEffects.weaponPool(fxDef.class, weaponType) else nil
			if own and fxDef and fxDef.pool ~= own and fxDef.pool ~= "common" then
				fxDef = nil
			end
			if fxDef and not taken[id] then
				taken[id] = true
				taken[fxDef.id] = true
				table.insert(ids, id)
				have[fxDef.tier] += 1
			end
		end
		if #ids ~= count then
			changed = true
		end
	end
	local needLegendary = rarityDef.legendaryEffects - have.legendary
	local needMythic = rarityDef.mythicEffects - have.mythic
	if needLegendary > 0 or needMythic > 0 then
		local rng = Rng.new(Rng.seedOf(if type(item.uid) == "string" then item.uid else item.id))
		local classId = classFor(def, classHint, rng)
		local element = elementOf(item, def)
		draw(ids, taken, classId, "legendary", needLegendary, rng, element, weaponType)
		draw(ids, taken, classId, "mythic", needMythic, rng, element, weaponType)
		changed = true
	end
	if changed then
		item.fx = if #ids > 0 then ids else nil
	end
	return changed
end

return ItemEffects
