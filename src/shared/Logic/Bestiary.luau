--!strict
-- Bestiary (S151c, docs/DESIGN.md §20c; data in Data/Bestiary). Pure: the kills and the drops seen of every entry in
-- the character's achievement branch, the tiers, the bestiary points, the family bonus, the region progress and the
-- view model of the window's tab. AchievementService feeds the kills and drops in and writes the changed leaves.
--
-- Save (no migration, AccountSchema template + reconcile), inside character.ach:
--   b  = { [entryId] = kills }                       (every variant counts; bosses: rewarded wins)
--   bd = { [entryId] = { [itemId] = true } }         (the drops of the entry seen by this character)

local Bosses = require("../Data/Bosses")
local Data = require("../Data/Bestiary")
local Monsters = require("../Data/Monsters")

type Entry = Data.Entry

export type Branch = { b: { [string]: number }, bd: { [string]: { [string]: boolean } } }
export type Kill = { id: string, kills: number, from: number, to: number } -- tiers before and after
export type Line = { key: string, args: { [string]: any }? }
export type Drop = { id: string, seen: boolean }
export type Row = {
	id: string,
	boss: boolean,
	known: boolean, -- killed at least once (the name shows)
	nameKey: string?, -- nil while unknown
	kills: number,
	tier: number,
	tiers: number, -- how many tiers
	goal: number, -- the next tier's kills (the last tier's when mastered)
	pct: number, -- 0..1 towards the next tier
	mastered: boolean,
}
export type View = Row & {
	region: string,
	family: string?, -- shown from the first kill
	levels: { min: number, max: number }?, -- REVEAL.portrait
	cave: boolean?,
	attack: { Line }?, -- REVEAL.portrait: melee / ranged, physical / magic
	drops: { Drop }?, -- REVEAL.drops
	defence: string?, -- REVEAL.drops: the family defence trait (Data/Families)
	weak: { Line }?, -- REVEAL.weak
	steps: { { goal: number, points: number, done: boolean } },
	familyPct: number, -- the character's bonus against the family now
}
export type RegionRow = { region: string, done: number, max: number, pct: number, complete: boolean, known: number }

local Bestiary = {}

local function number(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- Repairs the bestiary tables of a character achievement branch in place (garbage -> empty, bad numbers -> 0).
function Bestiary.repair(branch: any)
	if type(branch) ~= "table" then
		return
	end
	if type(branch.b) ~= "table" then
		branch.b = {}
	end
	if type(branch.bd) ~= "table" then
		branch.bd = {}
	end
	for id, value in branch.b do
		if type(value) ~= "number" or number(value) ~= value then
			branch.b[id] = number(value)
		end
	end
	for id, set in branch.bd do
		if type(set) ~= "table" then
			branch.bd[id] = {}
		end
	end
end

local function killsOf(branch: any, id: string): number
	local b = if type(branch) == "table" and type(branch.b) == "table" then branch.b else nil
	return if b then number(b[id]) else 0
end

-- The tier an entry reaches with `kills` (0 = none).
function Bestiary.tierOf(entry: Entry, kills: number): number
	local tier = 0
	for i, goal in entry.tiers do
		if kills >= goal then
			tier = i
		end
	end
	return tier
end

function Bestiary.kills(branch: any, id: string): number
	return killsOf(branch, id)
end

function Bestiary.tier(branch: any, id: string): number
	local entry = Data.get(id)
	return if entry then Bestiary.tierOf(entry, killsOf(branch, id)) else 0
end

function Bestiary.mastered(branch: any, entry: Entry): boolean
	return Bestiary.tierOf(entry, killsOf(branch, entry.id)) >= #entry.tiers
end

-- Adds `n` kills (default 1) of entry `id`. Nil for an unknown id or a bad count; otherwise the kills and the tiers
-- before and after (a crossed tier: to > from).
function Bestiary.addKill(branch: any, id: string, n: number?): Kill?
	local entry = Data.get(id)
	local count = if n == nil then 1 else number(n)
	if not entry or count <= 0 or type(branch) ~= "table" then
		return nil
	end
	Bestiary.repair(branch)
	local old = number(branch.b[id])
	local new = old + count
	branch.b[id] = new
	return { id = id, kills = new, from = Bestiary.tierOf(entry, old), to = Bestiary.tierOf(entry, new) }
end

-- Marks the drops of entry `id` seen; only ids the entry can drop count. Returns the newly seen ids.
function Bestiary.addDrops(branch: any, id: string, ids: any): { string }
	local out: { string } = {}
	local entry = Data.get(id)
	if not entry or type(branch) ~= "table" or type(ids) ~= "table" then
		return out
	end
	Bestiary.repair(branch)
	local set = branch.bd[id]
	for _, itemId in ids :: { any } do
		if type(itemId) == "string" and table.find(entry.drops, itemId) and not (set and set[itemId] == true) then
			if not set then
				set = {}
				branch.bd[id] = set
			end
			set[itemId] = true
			table.insert(out, itemId)
		end
	end
	return out
end

-- Points ------------------------------------------------------------------------------------------------------------

function Bestiary.pointsOf(entry: Entry, tier: number): number
	local total = 0
	for i = 1, math.min(tier, #entry.points) do
		total += entry.points[i]
	end
	return total
end

-- The bestiary points of a character branch (every reached tier).
function Bestiary.points(branch: any): number
	local total = 0
	for _, entry in Data.list do
		total += Bestiary.pointsOf(entry, Bestiary.tierOf(entry, killsOf(branch, entry.id)))
	end
	return total
end

function Bestiary.pointsMax(): number
	local total = 0
	for _, entry in Data.list do
		total += Bestiary.pointsOf(entry, #entry.tiers)
	end
	return total
end

-- Family bonus ----------------------------------------------------------------------------------------------------------

-- % damage against each family: FAMILY_PCT per mastered entry, at most FAMILY_CAP (families without one are absent).
function Bestiary.familyBonus(branch: any): { [string]: number }
	local out: { [string]: number } = {}
	for _, entry in Data.list do
		if Bestiary.mastered(branch, entry) then
			out[entry.family] = math.min(Data.FAMILY_CAP, (out[entry.family] or 0) + Data.FAMILY_PCT)
		end
	end
	return out
end

-- Regions -------------------------------------------------------------------------------------------------------------

-- (tiers reached, tiers in all) of a region.
function Bestiary.regionProgress(branch: any, region: string): (number, number)
	local done, max = 0, 0
	for _, entry in Data.forRegion(region) do
		done += Bestiary.tierOf(entry, killsOf(branch, entry.id))
		max += #entry.tiers
	end
	return done, max
end

function Bestiary.regionComplete(branch: any, region: string): boolean
	local done, max = Bestiary.regionProgress(branch, region)
	return max > 0 and done >= max
end

-- The complete regions in world order.
function Bestiary.completeRegions(branch: any): { string }
	local out: { string } = {}
	for _, region in Data.REGIONS do
		if Bestiary.regionComplete(branch, region) then
			table.insert(out, region)
		end
	end
	return out
end

function Bestiary.regions(branch: any): { RegionRow }
	local out: { RegionRow } = {}
	for _, region in Data.REGIONS do
		local done, max = Bestiary.regionProgress(branch, region)
		local known = 0
		for _, entry in Data.forRegion(region) do
			if killsOf(branch, entry.id) > 0 then
				known += 1
			end
		end
		table.insert(out, {
			region = region,
			done = done,
			max = max,
			pct = if max > 0 then done / max else 0,
			complete = max > 0 and done >= max,
			known = known,
		})
	end
	return out
end

-- Weaknesses ----------------------------------------------------------------------------------------------------------

-- The ratio over which armour or magic resistance counts as the weaker side.
local SIDE = 1.15

local function elementsOf(entry: Entry): { string }
	local out: { string } = {}
	if entry.boss then
		local def = Bosses.get(entry.id)
		for _, attack in (if def then def.attacks else {}) :: { any } do
			if attack.element and not table.find(out, attack.element) then
				table.insert(out, attack.element)
			end
		end
		table.sort(out)
	else
		local def = Monsters.get(entry.id)
		if def and def.element then
			table.insert(out, def.element)
		end
	end
	return out
end

-- What helps against the entry, from its numbers (armour against magic resistance, dodge, the element of its blows).
function Bestiary.weaknesses(entry: Entry): { Line }
	local out: { Line } = {}
	local defMul, mresMul, dodge = 1, 1, 0
	if entry.boss then
		local def = Bosses.get(entry.id)
		if def then
			defMul, mresMul = def.defMul, def.mresMul or 1
		end
	else
		local def = Monsters.get(entry.id)
		if def then
			defMul, mresMul, dodge = def.defMul, def.mresMul, def.dodge
		end
	end
	if defMul > mresMul * SIDE then
		table.insert(out, { key = "best.weak.magic" })
	elseif mresMul > defMul * SIDE then
		table.insert(out, { key = "best.weak.phys" })
	elseif defMul >= 1.3 and mresMul >= 1.3 then
		table.insert(out, { key = "best.weak.tough" })
	end
	if dodge > 0 then
		table.insert(out, { key = "best.weak.skills", args = { n = dodge } })
	end
	for _, element in elementsOf(entry) do
		table.insert(out, { key = "best.weak.element", args = { element = `element.{element}` } })
	end
	if #out == 0 then
		table.insert(out, { key = "best.weak.none" })
	end
	return out
end

local function attackOf(entry: Entry): { Line }
	local attack, kind = "melee", "phys"
	if entry.boss then
		local def = Bosses.get(entry.id)
		if def then
			attack, kind = def.attack, def.damageKind
		end
	else
		local def = Monsters.get(entry.id)
		if def then
			attack, kind = def.attack, def.damageKind
		end
	end
	return { { key = `best.attack.{attack}` }, { key = `best.damage.{kind}` } }
end

local function defenceOf(entry: Entry): string?
	if entry.boss then
		return nil
	end
	local def = Monsters.get(entry.id)
	return if def then def.defence else nil
end

-- View ----------------------------------------------------------------------------------------------------------------

function Bestiary.row(branch: any, entry: Entry): Row
	local kills = killsOf(branch, entry.id)
	local tier = Bestiary.tierOf(entry, kills)
	local tiers = #entry.tiers
	local mastered = tier >= tiers
	local goal = entry.tiers[math.min(tier + 1, tiers)]
	local from = if tier > 0 and not mastered then entry.tiers[tier] else 0
	local pct = if mastered then 1 else math.clamp((kills - from) / math.max(1, goal - from), 0, 1)
	return {
		id = entry.id,
		boss = entry.boss,
		known = kills > 0,
		nameKey = if kills > 0 then entry.nameKey else nil,
		kills = kills,
		tier = tier,
		tiers = tiers,
		goal = goal,
		pct = pct,
		mastered = mastered,
	}
end

-- The rows of a region in the data order (the monsters by level, then the bosses).
function Bestiary.rows(branch: any, region: string): { Row }
	local out: { Row } = {}
	for _, entry in Data.forRegion(region) do
		table.insert(out, Bestiary.row(branch, entry))
	end
	return out
end

-- Everything the window shows of entry `id`, as far as its tier reveals it (nil for an unknown id).
function Bestiary.view(branch: any, id: string): View?
	local entry = Data.get(id)
	if not entry then
		return nil
	end
	local row: any = Bestiary.row(branch, entry)
	local tier = row.tier
	row.region = entry.region
	row.family = if row.known then entry.family else nil
	if tier >= Data.REVEAL.portrait then
		row.levels = entry.levels
		row.cave = entry.cave
		row.attack = attackOf(entry)
	end
	if tier >= Data.REVEAL.drops then
		local seen = if type(branch) == "table" and type(branch.bd) == "table" then branch.bd[id] else nil
		local drops: { Drop } = {}
		for _, itemId in entry.drops do
			table.insert(drops, { id = itemId, seen = type(seen) == "table" and seen[itemId] == true })
		end
		row.drops = drops
		row.defence = defenceOf(entry)
	end
	if tier >= Data.REVEAL.weak then
		row.weak = Bestiary.weaknesses(entry)
	end
	local steps = {}
	for i, goal in entry.tiers do
		table.insert(steps, { goal = goal, points = entry.points[i], done = tier >= i })
	end
	row.steps = steps
	row.familyPct = Bestiary.familyBonus(branch)[entry.family] or 0
	return row :: View
end

return Bestiary
