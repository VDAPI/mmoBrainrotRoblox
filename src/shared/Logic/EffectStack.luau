--!strict
-- How effects on one entity combine (S53, ROZWOJ 7.1-7.2). Pure: StatusEffectService feeds it its active effects.
--   * Within a category of Data/BuffCategories only the strongest entry works (strength = sum of the category's
--     declared stats, or the effect's value; a tie goes to the newer one). Categories add up.
--   * Own entries (category "own", nil or an unknown id) always add up: they are the class balance.
--   * Damage reduction multiplies, 1 - prod(1 - r), capped at BuffCategories.caps.damageReduction.
-- Also the codec of the model attribute "Effects" the client icons read: "kind:expiresAt[:value]" joined by ";",
-- one entry per kind.

local BuffCategories = require("../Data/BuffCategories")

local EffectStack = {}

-- S63 (STATY 5): skillId of effects from items; their key is (kind, player, "item", category).
EffectStack.ITEM = "item"

local NO_STATS: { [string]: number } = table.freeze({})

export type Entry = {
	category: string?, -- nil or unknown id = own
	value: number?, -- kinds without stats: damageReduction, slow, vulnerability, armorBreak, misfortune
	stats: { [string]: number }?, -- statBuff
	pct: boolean?, -- statBuff: percentage modifiers instead of flat
	at: number, -- when it was (re)applied; a tie goes to the newer one
	item: boolean?, -- S63: from an item (skillId "item"): the item part of a split category
}

-- S63: the key of an effect (ROZWOJ 7.2).
export type Key = { kind: string, sourceKey: string, skillId: string?, category: string? }

-- S63: state of an effect under one key (restack).
export type Stack = { stacks: number, value: number, tickAmount: number?, expiresAt: number, nextTick: number? }
export type StackSpec = {
	unit: number,
	tickUnit: number?,
	maxStacks: number?,
	duration: number,
	now: number,
	tickInterval: number,
	-- S76: starting stacks of a moved effect (poison spread): the larger of these and the running ones, the later end
	stacks: number?,
	-- A refresh never ends the running effect sooner (Frostbite lives as long as the longest ice slow that set it).
	keepLonger: boolean?,
}

-- A statBuff being re-applied with the same key (merge).
export type Timed = { stats: { [string]: number }?, pct: boolean?, expiresAt: number }

-- One effect for the attribute (encode) and one decoded icon entry (decode).
-- S76: `stacks` (more than 1) shows as a number in the icon's corner.
export type Listed = { kind: string, expiresAt: number, value: number?, stacks: number? }
export type Shown = { kind: string, left: number, value: number?, stacks: number? }

function EffectStack.isOwn(category: string?): boolean
	-- An unknown id must never break a fight; the data test makes sure there is none.
	return category == nil or category == BuffCategories.OWN or BuffCategories.byId[category] == nil
end

function EffectStack.strength(entry: Entry): number
	local category = BuffCategories.get(entry.category)
	local declared = category and category.stats
	if declared then
		local stats = entry.stats or {}
		local total = 0
		for _, stat in declared do
			total += stats[stat] or 0
		end
		return total
	end
	return entry.value or 0
end

-- The strongest entry of every category (own entries excluded). The one place that decides a category's winner of
-- stat buffs; value categories with a skill / item split are read through EffectStack.value (S63).
local function winners(entries: { Entry }): { [string]: Entry }
	local best: { [string]: Entry } = {}
	local bestStrength: { [string]: number } = {}
	for _, entry in entries do
		if EffectStack.isOwn(entry.category) then
			continue
		end
		local id = entry.category :: string
		local strength = EffectStack.strength(entry)
		local current = best[id]
		if
			current == nil
			or strength > bestStrength[id]
			or (strength == bestStrength[id] and entry.at > current.at)
		then
			best[id] = entry
			bestStrength[id] = strength
		end
	end
	return best
end

-- The entries that work: every own entry plus the strongest of each category, in input order.
function EffectStack.select(entries: { Entry }): { Entry }
	local best = winners(entries)
	local out: { Entry } = {}
	for _, entry in entries do
		if EffectStack.isOwn(entry.category) or best[entry.category :: string] == entry then
			table.insert(out, entry)
		end
	end
	return out
end

-- Stat modifiers of the working statBuff entries: (flat, pct). A category with a cap (allyMove) adds at most the cap
-- per stat; own entries are never cut.
function EffectStack.stats(entries: { Entry }): ({ [string]: number }, { [string]: number })
	local flat: { [string]: number } = {}
	local pct: { [string]: number } = {}
	for _, entry in EffectStack.select(entries) do
		local target = if entry.pct then pct else flat
		local cap = if EffectStack.isOwn(entry.category) then nil else BuffCategories.caps[entry.category :: string]
		local stats: { [string]: number } = entry.stats or NO_STATS
		for stat, value in stats do
			local amount = if cap then math.min(value, cap) else value
			target[stat] = (target[stat] or 0) + amount
		end
	end
	return flat, pct
end

-- Percentages combined multiplicatively, each clamped to 0-100, the total capped.
function EffectStack.combine(values: { number }, cap: number): number
	local keep = 1
	for _, r in values do
		keep *= 1 - math.clamp(r, 0, 100) / 100
	end
	return math.min(cap, 100 * (1 - keep))
end

-- Total damage reduction in % of the working entries.
function EffectStack.reduction(entries: { Entry }): number
	local values = {}
	for _, entry in EffectStack.select(entries) do
		table.insert(values, entry.value or 0)
	end
	return EffectStack.combine(values, BuffCategories.caps.damageReduction)
end

-- Re-applying a statBuff with the same key (ROZWOJ 7.2): while the old one still runs with the same pct mode, the
-- stats merge (the newer value wins on a repeated stat) and it ends at the later end; otherwise the new one alone.
-- Returns copies, never mutates the input.
function EffectStack.merge(old: Timed?, new: Timed, now: number): ({ [string]: number }?, number)
	if old and old.expiresAt > now and (old.pct == true) == (new.pct == true) then
		local stats: { [string]: number } = table.clone(old.stats or NO_STATS)
		local newer: { [string]: number } = new.stats or NO_STATS
		for stat, value in newer do
			stats[stat] = value
		end
		return stats, math.max(old.expiresAt, new.expiresAt)
	end
	return if new.stats then table.clone(new.stats) else nil, new.expiresAt
end

-- True when two stat tables hold the same numbers (nil = empty). A refresh with the same stats keeps the stat cache
-- (S61, party auras every second).
function EffectStack.sameStats(a: { [string]: number }?, b: { [string]: number }?): boolean
	local left: { [string]: number } = a or NO_STATS
	local right: { [string]: number } = b or NO_STATS
	for stat, value in left do
		if right[stat] ~= value then
			return false
		end
	end
	for stat in right do
		if left[stat] == nil then
			return false
		end
	end
	return true
end

-- S63: true when the effect's key equals (kind, sourceKey, skillId, category); nil equals nil. StatusEffectService
-- finds an effect only through this, so the key rule has one owner.
function EffectStack.sameKey(entry: Key, kind: string, sourceKey: string, skillId: string?, category: string?): boolean
	return entry.kind == kind
		and entry.sourceKey == sourceKey
		and entry.skillId == skillId
		and entry.category == category
end

-- State of an effect applied under a key (STATY 5): a running effect with maxStacks > 1 gains a stack, all stacks
-- share one end time, stacks multiply value and tickAmount, a running effect keeps nextTick (S73: one stack too, so a
-- refresh never pushes the tick away). old = nil or expired: nextTick = now + tickInterval. Returns a new table.
function EffectStack.restack(old: Stack?, spec: StackSpec): Stack
	local now = spec.now
	local running = old ~= nil and old.expiresAt > now
	local limit = math.max(1, spec.maxStacks or 1)
	local stacks = 1
	if running and limit > 1 then
		stacks = math.min(limit, (old :: Stack).stacks + 1)
	end
	local expiresAt = now + spec.duration
	if spec.stacks then
		local start = math.clamp(math.floor(spec.stacks), 1, limit)
		stacks = if running then math.max((old :: Stack).stacks, start) else start
		if running then
			expiresAt = math.max((old :: Stack).expiresAt, expiresAt)
		end
	elseif spec.keepLonger and running then
		expiresAt = math.max((old :: Stack).expiresAt, expiresAt)
	end
	local tickUnit = spec.tickUnit
	local nextTick: number? = nil
	if tickUnit then
		local keep = if running then (old :: Stack).nextTick else nil
		nextTick = keep or now + spec.tickInterval
	end
	return {
		stacks = stacks,
		value = spec.unit * stacks,
		tickAmount = if tickUnit then tickUnit * stacks else nil,
		expiresAt = expiresAt,
		nextTick = nextTick,
	}
end

-- S63: publish the "Effects" attribute now? Structural changes always; a mere refresh at most once per interval.
function EffectStack.publishDue(structural: boolean, lastPublish: number?, now: number, interval: number): boolean
	return structural or lastPublish == nil or now - lastPublish >= interval
end

-- S63 (STATY 5, owner answer 14): the working value of a "value" category: the strongest entry, capped by
-- caps[id]; a split category adds the strongest skill entry and the strongest item entry (item part capped by
-- caps[id .. "Item"] when it exists), the sum capped by caps[id]. Negative values count as 0; an unknown category
-- has no cap.
function EffectStack.value(entries: { Entry }, categoryId: string): number
	local category = BuffCategories.get(categoryId)
	-- Strongest entry of the part `item` (nil = both parts).
	local function strongest(item: boolean?): number
		local top = 0
		for _, entry in entries do
			if entry.category == categoryId and (item == nil or (entry.item == true) == item) then
				top = math.max(top, EffectStack.strength(entry))
			end
		end
		return top
	end
	local total: number
	if category and category.split then
		local skillPart = strongest(false)
		local itemPart = strongest(true)
		local itemCap = BuffCategories.caps[categoryId .. "Item"]
		if itemCap then
			itemPart = math.min(itemPart, itemCap)
		end
		total = skillPart + itemPart
	else
		total = strongest(nil)
	end
	local cap = BuffCategories.caps[categoryId]
	return if cap then math.min(total, cap) else total
end

-- S65 (ROZWOJ 7.2, 14.4): damage over time refreshed with the unpaid rest ----------------------------------------

export type Running = { tickAmount: number, nextTick: number, expiresAt: number }
export type AccumulateSpec = { total: number, limit: number?, duration: number, now: number, interval: number }

-- Ticks a schedule still deals: at nextTick, nextTick + interval, ... while < expiresAt (tickEntity removes
-- the effect before a tick that falls on expiresAt).
function EffectStack.ticksBetween(nextTick: number, expiresAt: number, interval: number): number
	return math.max(0, math.ceil((expiresAt - nextTick) / interval - 1e-9))
end

-- S65 (ROZWOJ 7.2): refreshing a running DoT adds the unpaid rest to the new total; nextTick does not move.
-- `limit`: the pending sum is at most limit x total (3 sums of one hit for item bleeds and poisons).
-- Returns the new tickAmount and nextTick.
function EffectStack.accumulate(old: Running?, spec: AccumulateSpec): (number, number)
	local now, interval = spec.now, spec.interval
	local expiresAt = now + spec.duration
	if old == nil or old.expiresAt <= now then
		local nextTick = now + interval
		return spec.total / math.max(1, EffectStack.ticksBetween(nextTick, expiresAt, interval)), nextTick
	end
	-- A tick already due but not dealt yet belongs to the unpaid rest; nextTick keeps it.
	local unpaid = old.tickAmount * EffectStack.ticksBetween(old.nextTick, old.expiresAt, interval)
	local pending = unpaid + spec.total
	if spec.limit then
		pending = math.min(pending, spec.limit * spec.total)
	end
	local nextTick = old.nextTick
	return pending / math.max(1, EffectStack.ticksBetween(nextTick, expiresAt, interval)), nextTick
end

-- Attribute "Effects" ----------------------------------------------------------------------------------------

-- Kinds whose value is a percentage shown to the player (an absorb shield keeps its remaining points in value).
EffectStack.VALUE_KINDS = table.freeze({
	slow = true,
	vulnerability = true,
	armorBreak = true,
	damageReduction = true,
	manaShield = true,
	nextShot = true,
	intercept = true, -- S61
	misfortune = true, -- S61
	attackSlow = true, -- S63
	weaken = true, -- S63
	nextBasic = true, -- S65
	runeSeal = true, -- S65
	frostbite = true, -- S65
} :: { [string]: boolean })

type Group = { kind: string, at: number, value: number?, stacks: number? }

-- Groups by kind (latest / biggest `at`, highest value), sorted by kind.
local function grouped(items: { Group }): { Group }
	local byKind: { [string]: Group } = {}
	local order: { Group } = {}
	for _, item in items do
		local group = byKind[item.kind]
		if group == nil then
			local created: Group = { kind = item.kind, at = item.at, value = item.value, stacks = item.stacks }
			byKind[item.kind] = created
			table.insert(order, created)
		else
			group.at = math.max(group.at, item.at)
			if item.value and (group.value == nil or item.value > group.value) then
				group.value = item.value
			end
			if item.stacks and (group.stacks == nil or item.stacks > group.stacks) then
				group.stacks = item.stacks
			end
		end
	end
	table.sort(order, function(a, b)
		return a.kind < b.kind
	end)
	return order
end

-- "kind:expiresAt[:value[:stacks]]" per kind (latest end, strongest value, most stacks), sorted by kind; nil when
-- nothing is active. S76: stacks only above 1, the value may be empty then ("poison:12.5::3").
function EffectStack.encode(list: { Listed }, now: number): string?
	local items: { Group } = {}
	for _, effect in list do
		if effect.expiresAt > now then
			local value = effect.value
			local shown = if EffectStack.VALUE_KINDS[effect.kind] and value and value > 0 then value else nil
			local stacks = if effect.stacks and effect.stacks > 1 then math.floor(effect.stacks) else nil
			table.insert(items, { kind = effect.kind, at = effect.expiresAt, value = shown, stacks = stacks })
		end
	end
	local parts = {}
	for _, group in grouped(items) do
		local ends = math.floor(group.at * 10) / 10
		local value = group.value
		local text = if value then `{group.kind}:{ends}:{math.floor(value + 0.5)}` else `{group.kind}:{ends}`
		if group.stacks then
			text = if value then `{text}:{group.stacks}` else `{text}::{group.stacks}`
		end
		table.insert(parts, text)
	end
	return if #parts > 0 then table.concat(parts, ";") else nil
end

-- Active entries of the attribute, one per kind (longest time left, highest value), sorted by kind. Reads the old
-- format without values too; anything malformed is skipped.
function EffectStack.decode(raw: any, now: number): { Shown }
	if type(raw) ~= "string" then
		return {}
	end
	local items: { Group } = {}
	for part in string.gmatch(raw, "[^;]+") do
		local kind, ends, value, stacks = string.match(part, "^(%a+):([%d%.]+):?(%d*):?(%d*)$")
		local expiresAt = tonumber(ends)
		if kind and expiresAt and expiresAt > now then
			table.insert(items, {
				kind = kind,
				at = expiresAt,
				value = if value ~= "" then tonumber(value) else nil,
				stacks = if stacks ~= "" then tonumber(stacks) else nil,
			})
		end
	end
	local out: { Shown } = {}
	for _, group in grouped(items) do
		table.insert(out, { kind = group.kind, left = group.at - now, value = group.value, stacks = group.stacks })
	end

	return out
end

-- S80: stacks of the shown entry of `kind` in the attribute (1 when the text has no count, 0 without the kind):
-- Arcane Charges on the skill bar, the tooltip and the orbs around the mage.
function EffectStack.stacksOf(raw: any, kind: string, now: number): number
	for _, shown in EffectStack.decode(raw, now) do
		if shown.kind == kind then
			return shown.stacks or 1
		end
	end
	return 0
end

return EffectStack
