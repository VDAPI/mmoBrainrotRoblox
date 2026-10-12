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

local NO_STATS: { [string]: number } = table.freeze({})

export type Entry = {
	category: string?, -- nil or unknown id = own
	value: number?, -- kinds without stats: damageReduction, slow, vulnerability, armorBreak, misfortune
	stats: { [string]: number }?, -- statBuff
	pct: boolean?, -- statBuff: percentage modifiers instead of flat
	at: number, -- when it was (re)applied; a tie goes to the newer one
}

-- A statBuff being re-applied with the same key (merge).
export type Timed = { stats: { [string]: number }?, pct: boolean?, expiresAt: number }

-- One effect for the attribute (encode) and one decoded icon entry (decode).
export type Listed = { kind: string, expiresAt: number, value: number? }
export type Shown = { kind: string, left: number, value: number? }

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

-- The strongest entry of every category (own entries excluded). The one place that decides a category's winner,
-- so a later split (skill part / item part, STATY 5) changes only this function.
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

-- Attribute "Effects" ----------------------------------------------------------------------------------------

-- Kinds whose value is a percentage shown to the player (an absorb shield keeps its remaining points in value).
EffectStack.VALUE_KINDS = table.freeze({
	slow = true,
	vulnerability = true,
	armorBreak = true,
	damageReduction = true,
	manaShield = true,
	nextShot = true,
} :: { [string]: boolean })

type Group = { kind: string, at: number, value: number? }

-- Groups by kind (latest / biggest `at`, highest value), sorted by kind.
local function grouped(items: { Group }): { Group }
	local byKind: { [string]: Group } = {}
	local order: { Group } = {}
	for _, item in items do
		local group = byKind[item.kind]
		if group == nil then
			local created: Group = { kind = item.kind, at = item.at, value = item.value }
			byKind[item.kind] = created
			table.insert(order, created)
		else
			group.at = math.max(group.at, item.at)
			if item.value and (group.value == nil or item.value > group.value) then
				group.value = item.value
			end
		end
	end
	table.sort(order, function(a, b)
		return a.kind < b.kind
	end)
	return order
end

-- "kind:expiresAt[:value]" per kind (latest end, strongest value), sorted by kind; nil when nothing is active.
function EffectStack.encode(list: { Listed }, now: number): string?
	local items: { Group } = {}
	for _, effect in list do
		if effect.expiresAt > now then
			local value = effect.value
			local shown = if EffectStack.VALUE_KINDS[effect.kind] and value and value > 0 then value else nil
			table.insert(items, { kind = effect.kind, at = effect.expiresAt, value = shown })
		end
	end
	local parts = {}
	for _, group in grouped(items) do
		local ends = math.floor(group.at * 10) / 10
		local value = group.value
		table.insert(parts, if value then `{group.kind}:{ends}:{math.floor(value + 0.5)}` else `{group.kind}:{ends}`)
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
		local kind, ends, value = string.match(part, "^(%a+):([%d%.]+):?(%d*)$")
		local expiresAt = tonumber(ends)
		if kind and expiresAt and expiresAt > now then
			table.insert(items, { kind = kind, at = expiresAt, value = if value ~= "" then tonumber(value) else nil })
		end
	end
	local out: { Shown } = {}
	for _, group in grouped(items) do
		table.insert(out, { kind = group.kind, left = group.at - now, value = group.value })
	end
	return out
end

return EffectStack
