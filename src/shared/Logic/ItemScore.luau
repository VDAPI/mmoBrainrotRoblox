--!strict
-- How good an item is for a class and its main path ("Better item!", DESIGN §5.9; S20, rebuilt in S67). Weights in
-- Data/ItemWeights: every stat, hook and trait lands on one of four axes (damage, survival, support, utility);
-- situational lines (families, classes, bosses, elites) count half; the trait counts once by its STATY 14 estimate.
-- A main path with `itemWeights` multiplies the class weights. Pure.

local Bonuses = require("../Data/Bonuses")
local Classes = require("../Data/Classes")
local ItemRoll = require("./ItemRoll")
local ItemTraits = require("../Data/ItemTraits")
local ItemWeights = require("../Data/ItemWeights")
local Items = require("../Data/Items")
local PathData = require("../Data/Paths")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance
type Weight = ItemWeights.Weight

export type Context = { classId: string, level: number?, pathId: string?, weights: ItemWeights.ItemWeights? }
export type Breakdown = { dmg: number, surv: number, support: number, util: number, total: number }

local ItemScore = {}

ItemScore.PCT_POINTS = ItemWeights.PCT_POINTS -- S68 converts points to % with it

local function contextOf(ctx: Context | string): Context
	if type(ctx) == "string" then
		return { classId = ctx }
	end
	return ctx
end

-- A Data/Bonuses line id becomes the stat or hook its value lands under; anything else stays.
local function resolveKey(key: string): string
	local def = Bonuses.get(key)
	if def then
		local read = if def.replacedBy then Bonuses.get(def.replacedBy) or def else def
		return read.hook or read.stat or key
	end
	return key
end

-- Path multipliers with line ids resolved; nil when the context has none.
local function pathWeights(ctx: Context): ItemWeights.ItemWeights?
	local weights = ctx.weights
	if not weights and ctx.pathId then
		local path = PathData.byId[ctx.pathId]
		if path and path.class == ctx.classId then
			weights = path.itemWeights
		end
	end
	if not weights then
		return nil
	end
	local stats: { [string]: number } = {}
	local raw: { [string]: number } = weights.stats or {}
	for key, mul in raw do
		stats[resolveKey(key)] = mul
	end
	return { axes = weights.axes, stats = stats, traits = weights.traits }
end

local function prefixWeight(id: string): Weight?
	for prefix, weight in ItemWeights.prefixHooks do
		if string.sub(id, 1, #prefix) == prefix then
			return weight
		end
	end
	return nil
end

local function statWeight(classId: string, stat: string): Weight?
	local byClass = ItemWeights.class[classId]
	return (byClass and byClass[stat]) or ItemWeights.common[stat]
end

local function hookWeight(classId: string, id: string): Weight
	local byClass = ItemWeights.class[classId]
	return (byClass and byClass[id]) or ItemWeights.hooks[id] or prefixWeight(id) or ItemWeights.HOOK_DEFAULT
end

local function without(source: { [string]: number }, minus: { [string]: number }?): { [string]: number }
	local out = table.clone(source)
	local list: { [string]: number } = minus or {}
	for key, v in list do
		out[key] = (out[key] or 0) - v
	end
	return out
end

-- Points of an item on each axis (before axis multipliers) and the total for the context.
function ItemScore.breakdown(item: ItemInstance, context: Context | string): Breakdown
	local ctx = contextOf(context)
	local classId = ctx.classId
	local path = pathWeights(ctx)
	local pathStats: { [string]: number } = if path then path.stats or {} else {}
	local out: Breakdown = { dmg = 0, surv = 0, support = 0, util = 0, total = 0 }
	local function add(axis: string, points: number)
		(out :: any)[axis] += points
	end

	local stats = ItemRoll.itemStats(item)
	local trait = stats.trait
	local contrib = trait and trait.contrib
	-- Every trait counts once: what itemStats added from it leaves the stats and the trait is valued as a whole.
	local flat = without(stats.flat, contrib and contrib.flat)
	local hooks = without(stats.hooks, contrib and contrib.hooks)

	for stat, value in flat do
		local weight = statWeight(classId, stat)
		if weight and value ~= 0 then
			add(weight.axis, value * weight.w * (pathStats[stat] or 1))
		end
	end
	for stat, value in stats.pct do
		local weight = statWeight(classId, stat)
		if weight and weight.w > 0 then
			add(weight.axis, value * ItemWeights.PCT_POINTS * (pathStats[stat] or 1))
		end
	end
	for id, value in hooks do
		if value ~= 0 then
			local weight = hookWeight(classId, id)
			local situational = if weight.situational then ItemWeights.SITUATIONAL else 1
			add(weight.axis, value * weight.w * situational * (pathStats[id] or 1))
		end
	end
	if trait then
		local weight = ItemWeights.traits[trait.id]
		if weight then
			local mul = if path and path.traits then path.traits[trait.id] or 1 else 1
			add(weight.axis, weight.pct * ItemWeights.PCT_POINTS * trait.power * mul)
		end
	end
	local weapon = stats.weapon
	if weapon then
		local class = Classes.get(classId)
		local magic = class ~= nil and class.basicAttack.kind == "magic"
		add("dmg", (if magic then weapon.mdmg else weapon.dmg) * weapon.speed * ItemWeights.WEAPON)
	end

	local classAxes: { [string]: number } = ItemWeights.axes[classId] or {}
	local pathAxes: { [string]: number } = if path then path.axes or {} else {}
	for _, axis in ItemWeights.AXES do
		out.total += (out :: any)[axis] * (classAxes[axis] or 1) * (pathAxes[axis] or 1)
	end
	return out
end

function ItemScore.score(item: ItemInstance, ctx: Context | string): number
	return ItemScore.breakdown(item, ctx).total
end

-- True when `candidate` is equippable by the character and scores higher than what it would replace
-- (`equipped` nil = empty slot).
function ItemScore.isUpgrade(
	candidate: ItemInstance,
	equipped: ItemInstance?,
	context: Context | string,
	level: number
): boolean
	local ctx = contextOf(context)
	local def = Items.get(candidate.id)
	if not def or not def.slot or def.category ~= "equipment" then
		return false
	end
	if def.classes and not table.find(def.classes, ctx.classId) then
		return false
	end
	if ItemRoll.requiredLevel(candidate) > level then
		return false
	end
	if not equipped then
		return true
	end
	return ItemScore.score(candidate, ctx) > ItemScore.score(equipped, ctx) * ItemWeights.UPGRADE_MARGIN
end

-- Whether a stat / hook key (after resolving line ids) has any weight: common, some class, hooks or a prefix.
local function knownKey(key: string): boolean
	if ItemWeights.common[key] or ItemWeights.hooks[key] or prefixWeight(key) then
		return true
	end
	for _, byClass in ItemWeights.class do
		if byClass[key] then
			return true
		end
	end
	return false
end

ItemScore.knownKey = function(key: string): boolean
	return knownKey(resolveKey(key))
end

-- Unknown keys of path weights (paths.spec): axes outside the four, stats without a weight, unknown traits.
function ItemScore.validateWeights(weights: ItemWeights.ItemWeights): { string }
	local problems: { string } = {}
	local axes: { [string]: number } = weights.axes or {}
	local stats: { [string]: number } = weights.stats or {}
	local traits: { [string]: number } = weights.traits or {}
	for axis in axes do
		if not table.find(ItemWeights.AXES, axis :: any) then
			table.insert(problems, `axes.{axis}`)
		end
	end
	for key in stats do
		if not knownKey(resolveKey(key)) then
			table.insert(problems, `stats.{key}`)
		end
	end
	for id in traits do
		if not ItemTraits.get(id) then
			table.insert(problems, `traits.{id}`)
		end
	end
	table.sort(problems)
	return problems
end

return ItemScore
