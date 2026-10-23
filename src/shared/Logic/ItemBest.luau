--!strict
-- "Best roll" of an item for a class (dev panel grants, owner 2026-10-23). Deterministic, pure, no Rng: the same rules
-- as ItemRoll.rollItem (the class-filtered pool of the item's bonus group without lines weighted 0 for its type,
-- Rarities.bonusMax lines without repeats, ItemEffects.pool per tier with the Mage element and the weapon's own pool),
-- but every line rolls at the top of its range and the lines and effects are the ones ItemScore values most for the
-- class (Data/ItemWeights: class, main path and the weapon pool). Situational lines (one family, one class, bosses,
-- elites: ItemWeights `situational`) only fill when nothing else is left. Ties: higher type affinity (Data/ItemTraits), then
-- pool / data order. A set shares `taken` so an effect id is not repeated (one id works once) while others remain.

local Bonuses = require("../Data/Bonuses")
local Elements = require("../Data/Elements")
local ItemEffects = require("./ItemEffects")
local ItemRoll = require("./ItemRoll")
local ItemScore = require("./ItemScore")
local ItemTraits = require("../Data/ItemTraits")
local ItemWeights = require("../Data/ItemWeights")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local SkillPools = require("./SkillPools")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

export type Options = {
	up: number?, -- upgrade level 0..9
	element: string?, -- a Mage weapon's element (invalid or nil: Elements.DEFAULT)
	taken: { [string]: boolean }?, -- effect ids already on other items of the set (filled by roll)
}

local ItemBest = {}

local function contextOf(ctx: ItemScore.Context | string): ItemScore.Context
	if type(ctx) == "string" then
		return { classId = ctx }
	end
	return table.clone(ctx)
end

-- The class an item rolls for: the context's class when the item fits it, else the item's first class, else (a
-- class-free item) the context's class.
function ItemBest.classFor(def: Items.ItemDef, classId: string): string
	local classes = def.classes
	if classes and #classes > 0 and not table.find(classes, classId) then
		return classes[1]
	end
	return classId
end

-- Line ids to try for a pool id: a marker (Bonuses.params) becomes its first variant (all variants weigh the same).
local function concrete(id: string): string?
	if Bonuses.isParam(id) then
		return Bonuses.variants(id)[1]
	end
	return id
end

-- A line that works only against one family, one class, bosses or elites (Data/ItemWeights situational hooks).
local function situational(id: string): boolean
	local def = Bonuses.get(id)
	local hook = def and def.hook
	if not hook then
		return false
	end
	local weight = ItemWeights.hooks[hook]
	if not weight then
		for prefix, w in ItemWeights.prefixHooks do
			if string.sub(hook, 1, #prefix) == prefix then
				weight = w
				break
			end
		end
	end
	return weight ~= nil and weight.situational == true
end

type Candidate = { id: string, gain: number, weight: number, order: number, situational: boolean? }

local function better(a: Candidate, b: Candidate): boolean
	if (a.situational == true) ~= (b.situational == true) then
		return b.situational == true
	end
	if math.abs(a.gain - b.gain) > 1e-9 then
		return a.gain > b.gain
	end
	if a.weight ~= b.weight then
		return a.weight > b.weight
	end
	return a.order < b.order
end

-- The best item instance of `defId` at `ilvl` / `rarity` for the context's class. Non-equipment: a stack of one;
-- named boss items: their fixed lines and effects (as ItemRoll.rollItem).
function ItemBest.roll(
	defId: string,
	ilvl: number,
	rarity: number,
	uid: string,
	context: ItemScore.Context | string,
	opts: Options?
): ItemInstance
	local def = Items.get(defId)
	assert(def, `ItemBest: unknown item {defId}`)
	local options: Options = opts or {}
	local up = math.clamp(math.floor(options.up or 0), 0, 9)
	if def.category ~= "equipment" or def.fixedBonuses then
		-- no draw happens on these paths (the Rng is never read)
		local item = ItemRoll.rollItem(defId, ilvl, rarity, Rng.new(1), uid)
		if def.category == "equipment" then
			item.up = up
		end
		return item
	end

	local ctx = contextOf(context)
	local classId = ItemBest.classFor(def, ctx.classId)
	if classId ~= ctx.classId then
		ctx = { classId = classId }
	end
	local rarityId = math.clamp(math.floor(rarity), Rarities.COMMON, Rarities.MAX)
	local rarityDef = Rarities.get(rarityId)
	local level = math.max(1, math.floor(ilvl))
	local el: string? = nil
	if def.elemental then
		el = if options.element and Elements.isWeaponElement(options.element) then options.element else Elements.DEFAULT
	end
	local weaponType = if def.slot == "weapon" then def.type else nil
	if weaponType then
		-- a weapon switches the pool: its own effects count in full
		ctx.poolId = SkillPools.poolOf(classId, { main = weaponType }, el)
	end

	local item: ItemInstance = {
		uid = uid,
		id = defId,
		rarity = rarityId,
		ilvl = level,
		bonuses = {},
		up = up,
		bound = false,
		n = 1,
		el = el,
		rv = Rarities.RV,
	}
	local base = ItemScore.score(item, ctx)

	-- Lines: each scored alone at its top value (lines add up, so the top `bonusMax` by gain is the best set).
	local weights = ItemRoll.poolWeights(defId, classId)
	local lines: { Candidate } = {}
	for order, poolId in ItemRoll.bonusPool(defId, classId) do
		local id = concrete(poolId)
		if id and Bonuses.get(id) then
			item.bonuses = { { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, 1) } }
			table.insert(lines, {
				id = id,
				gain = ItemScore.score(item, ctx) - base,
				weight = weights[poolId] or ItemTraits.weight(def.type, poolId, classId),
				order = order,
				situational = situational(id),
			})
		end
	end
	table.sort(lines, better)
	local bonuses: { Types.Bonus } = {}
	for i = 1, math.min(rarityDef.bonusMax, #lines) do
		local id = lines[i].id
		table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, 1) })
	end
	item.bonuses = {}

	-- Effects: the best of each tier's pool (untaken first), legendary before mythic like ItemEffects.roll.
	local taken = options.taken or {}
	local fx: { string } = {}
	local function pick(tier: ItemEffects.Tier, count: number)
		if count <= 0 then
			return
		end
		local candidates: { Candidate } = {}
		for order, effect in ItemEffects.pool(classId, tier, el, weaponType) do
			if not table.find(fx, effect.id) then
				item.fx = { effect.id }
				local gain = ItemScore.score(item, ctx) - base
				table.insert(candidates, {
					id = effect.id,
					-- an effect already in the set adds nothing more; it only fills when nothing else is left
					gain = if taken[effect.id] then -1e9 + gain else gain,
					weight = ItemScore.effectPoints(effect),
					order = order,
				})
			end
		end
		item.fx = nil
		table.sort(candidates, better)
		for i = 1, math.min(count, #candidates) do
			table.insert(fx, candidates[i].id)
			taken[candidates[i].id] = true
		end
	end
	pick("legendary", rarityDef.legendaryEffects)
	pick("mythic", rarityDef.mythicEffects)

	item.bonuses = bonuses
	item.fx = if #fx > 0 then fx else nil
	return item
end

-- A whole set (Logic/DevPreset pieces, weapon first): every piece at its best for the class, the set's weapon pool
-- deciding which effects count in full, no effect id twice while others remain.
function ItemBest.set(
	pieces: { { slot: string, id: string } },
	ilvl: number,
	rarity: number,
	context: ItemScore.Context | string,
	newUid: () -> string,
	opts: Options?
): { ItemInstance }
	local ctx = contextOf(context)
	local options: Options = table.clone(opts or {})
	options.taken = options.taken or {}
	for _, piece in pieces do
		local def = Items.get(piece.id)
		if piece.slot == "weapon" and def and ItemBest.classFor(def, ctx.classId) == ctx.classId then
			local el = if def.elemental
				then (if options.element and Elements.isWeaponElement(options.element)
					then options.element
					else Elements.DEFAULT)
				else nil
			ctx.poolId = SkillPools.poolOf(ctx.classId, { main = def.type }, el)
		end
	end
	local out: { ItemInstance } = {}
	for _, piece in pieces do
		table.insert(out, ItemBest.roll(piece.id, ilvl, rarity, newUid(), ctx, options))
	end
	return out
end

return ItemBest
