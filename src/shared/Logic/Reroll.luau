--!strict
-- S134j (docs/DESIGN.md §6a, docs/STATY.md §9–§10): bonus reroll at the smith. Pure (Lune and Roblox).
--   * Only the random regular lines of `bonuses` (Data/Bonuses tier "regular"): never the base stats, the trait, the
--     skill effects `fx` (S134g) nor named boss items (`fixedBonuses`). Every rarity with lines (Mythic too).
--   * The first reroll locks the choice: `rr.i` is the only line that can be rerolled on that item from then on.
--   * A reroll draws a new line from the item's weighted pool (ItemRoll.poolWeights; class of the character when the
--     item fits it) without the stats of the other lines (and their markers); the current stat stays in the pool.
--     A marker expands to a random variant (ItemRoll.expandParam without a context), the value rolls like a drop
--     (ItemRoll.rollBonusValue for the item's ilvl and rarity).
--   * Cost: Config.Reroll essence by rarity + gold on the upgrade gold curve, x min(1 + growth x n, growthCap) with
--     n = rerolls already done on the item (`rr.n`, it travels with the item). The Stone of Transmutation
--     (`reroll_stone`) pays the essence of one attempt, never the gold.
-- Randomness only through the given Rng (the server's in BlacksmithService); the client previews with the same code.

local Bonuses = require("../Data/Bonuses")
local Config = require("../Config")
local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local StatGroups = require("./StatGroups")
local Types = require("../Types")
local Upgrade = require("./Upgrade")

type ItemInstance = Types.ItemInstance

local Reroll = {}

-- The premium item that pays the essence of one attempt (Data/Items/Consumables, Data/Products).
Reroll.STONE = "reroll_stone"
-- S156: the premium item that rerolls every regular line of an item at once (Reroll.rollAll).
Reroll.SCROLL = "transmute_scroll"

export type State = { line: number?, n: number }
export type Cost = Upgrade.Cost
export type Outcome = { stat: string, chance: number, min: number, max: number, marker: boolean }

local function isWhole(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value == math.floor(value)
end

local function levelOf(item: ItemInstance): number
	return math.max(1, math.floor(tonumber(item.ilvl) or 1))
end

local function rarityOf(item: ItemInstance): number
	return math.clamp(math.floor(tonumber(item.rarity) or Rarities.COMMON), Rarities.COMMON, Rarities.MAX)
end

-- Whether line `index` of `item` is a random regular line (the only kind a reroll touches).
local function isRegular(item: ItemInstance, index: number): boolean
	local bonuses = item.bonuses
	if type(bonuses) ~= "table" or not isWhole(index) or index < 1 or index > #bonuses then
		return false
	end
	local line = bonuses[index]
	local def = if type(line) == "table" and type(line.stat) == "string" then Bonuses.get(line.stat) else nil
	return def ~= nil and def.tier == "regular"
end

-- The reroll state of an item, type-safe: `n` a whole number >= 0 (anything else 0); `line` the locked line when
-- `rr.i` is a whole index inside `bonuses` pointing at a rerollable line, else nil (the choice is open again, the
-- count stays: an index left outside by a data change never resets the cost).
function Reroll.state(item: ItemInstance): State
	local rr: any = (item :: any).rr
	if type(rr) ~= "table" then
		return { line = nil, n = 0 }
	end
	local n = if isWhole(rr.n) and rr.n >= 0 then rr.n :: number else 0
	local line = if isWhole(rr.i) and isRegular(item, rr.i) then rr.i :: number else nil
	return { line = line, n = n }
end

-- Whether the item can be rerolled at all (equipment, not a named boss item, at least one regular line).
function Reroll.eligible(item: ItemInstance): (boolean, string?)
	local def = Items.get(item.id)
	if not def or def.category ~= "equipment" then
		return false, "smith.reroll.error.noLines"
	end
	if def.fixedBonuses then
		return false, "smith.reroll.error.fixed"
	end
	for index = 1, #(item.bonuses :: { any }) do
		if isRegular(item, index) then
			return true, nil
		end
	end
	return false, "smith.reroll.error.noLines"
end

-- Whether line `index` can be rerolled now: a regular line of an eligible item and, once the choice is locked, the
-- locked line only.
function Reroll.canLine(item: ItemInstance, index: number): (boolean, string?)
	local ok, err = Reroll.eligible(item)
	if not ok then
		return false, err
	end
	if not isRegular(item, index) then
		return false, "smith.reroll.error.notRegular"
	end
	local locked = Reroll.state(item).line
	if locked ~= nil and locked ~= index then
		return false, "smith.reroll.error.lockedOther"
	end
	return true, nil
end

-- The class the pool is filtered for: the character's when the item fits it (no class list, or the class on it),
-- else nil (every class of the item's definition).
function Reroll.classFor(item: ItemInstance, classId: string?): string?
	local def = Items.get(item.id)
	if not def or not classId then
		return nil
	end
	if def.classes == nil or table.find(def.classes, classId) then
		return classId
	end
	return nil
end

-- Pool weights of line `index`: ItemRoll.poolWeights without the stats of the other lines (a legacy line also
-- blocks its replacement) and without the markers they come from (one variant of a marker on an item, like a drop).
-- The current stat of the line stays.
function Reroll.pool(item: ItemInstance, index: number, classId: string?): { [string]: number }
	local weights = ItemRoll.poolWeights(item.id, Reroll.classFor(item, classId))
	for j, line in item.bonuses :: { any } do
		if j ~= index and type(line) == "table" and type(line.stat) == "string" then
			weights[line.stat] = nil
			local def = Bonuses.get(line.stat)
			if def then
				if def.param then
					weights[def.param] = nil
				end
				if def.replacedBy then
					weights[def.replacedBy] = nil
				end
			end
		end
	end
	return weights
end

-- Rolls a new line for `index` (pool, marker, value). Does not change the item.
function Reroll.roll(item: ItemInstance, index: number, classId: string?, rng: Rng.Rng): Types.Bonus
	local pool = Reroll.pool(item, index, classId)
	assert(next(pool) ~= nil, "Reroll: empty pool")
	local id = rng:weighted(pool)
	if Bonuses.isParam(id) then
		id = ItemRoll.expandParam(id, rng, nil)
	end
	return { stat = id, v = ItemRoll.rollBonusValue(id, levelOf(item), rarityOf(item), rng:next()) }
end

-- Writes the rolled line into `index` (a new bonuses list, the order unchanged) and counts the reroll; the first
-- reroll locks the choice on `index`. Nothing else of the item changes.
function Reroll.apply(item: ItemInstance, index: number, line: Types.Bonus)
	local bonuses = table.clone(item.bonuses)
	bonuses[index] = { stat = line.stat, v = line.v }
	item.bonuses = bonuses
	item.rr = { i = index, n = Reroll.state(item).n + 1 }
end

-- The range of a pool entry on the item as the tooltip shows it (x ItemRoll.lineMultiplier: two-handed weapons).
local function rangeOf(item: ItemInstance, id: string): (number, number)
	local low, high = ItemRoll.bonusRange(id, levelOf(item), rarityOf(item))
	local mul = ItemRoll.lineMultiplier(item, id)
	return low * mul, high * mul
end

-- What line `index` can become: every pool entry with its chance (weight / sum; a marker is one entry with its
-- variants' range) and value range, in the tooltip's group order (Logic/StatGroups). Chances add up to 1.
function Reroll.preview(item: ItemInstance, index: number, classId: string?): { Outcome }
	local pool = Reroll.pool(item, index, classId)
	local total = 0
	for _, w in pool do
		total += w
	end
	local out: { Outcome } = {}
	if total <= 0 then
		return out
	end
	local ranks: { [string]: number } = {}
	for id, w in pool do
		local marker = Bonuses.isParam(id)
		local sample = if marker then Bonuses.variants(id)[1] else id
		if sample then
			local low, high = rangeOf(item, sample)
			ranks[id] = StatGroups.rank(sample)
			table.insert(out, { stat = id, chance = w / total, min = low, max = high, marker = marker })
		end
	end
	table.sort(out, function(a: Outcome, b: Outcome): boolean
		if ranks[a.stat] ~= ranks[b.stat] then
			return ranks[a.stat] < ranks[b.stat]
		end
		return a.stat < b.stat
	end)
	return out
end

-- Cost multiplier of the attempt after `n` earlier ones: min(1 + growth x n, growthCap).
function Reroll.growth(n: number): number
	local c = Config.Reroll
	return math.min(1 + c.growth * math.max(0, n), c.growthCap)
end

-- Cost of the attempt after `n` earlier rerolls of the item (the model and the "next" line of the window).
function Reroll.costAt(item: ItemInstance, n: number): Cost
	local c = Config.Reroll
	local ilvl = levelOf(item)
	local mul = Reroll.growth(n)
	local gold = math.floor(ilvl * Upgrade.goldPerIlvl(ilvl) * c.goldMul * mul + 0.5)
	local materials = {}
	local essence = (c.essence :: { [string]: { id: string, n: number } })[Rarities.get(rarityOf(item)).key]
	if essence then
		table.insert(materials, { id = essence.id, n = math.ceil(essence.n * mul - 1e-9) })
	end
	return { gold = gold, materials = materials }
end

-- Cost of the item's next reroll.
function Reroll.cost(item: ItemInstance): Cost
	return Reroll.costAt(item, Reroll.state(item).n)
end

-- The same attempt paid with a Stone of Transmutation: the gold stays, no essence.
function Reroll.costWithStone(item: ItemInstance): Cost
	return { gold = Reroll.cost(item).gold, materials = {} }
end

-- S156 (owner 2026-10-20): the Scroll of Transformation. Every regular line of the item, top to bottom, each drawn from
-- its pool against the lines already rolled (no two lines of one stat, like a drop); the lock (`rr.i`) does not limit
-- it and stays. Returns the new bonuses list and the changes; does not change the item.
export type Change = { index: number, old: Types.Bonus, new: Types.Bonus }
function Reroll.rollAll(item: ItemInstance, classId: string?, rng: Rng.Rng): ({ Types.Bonus }, { Change })
	local work: any = table.clone(item)
	work.bonuses = table.clone(item.bonuses)
	local changes: { Change } = {}
	for index = 1, #work.bonuses do
		if isRegular(work, index) and next(Reroll.pool(work, index, classId)) ~= nil then
			local old = work.bonuses[index]
			local line = Reroll.roll(work, index, classId, rng)
			work.bonuses[index] = { stat = line.stat, v = line.v }
			table.insert(changes, { index = index, old = { stat = old.stat, v = old.v }, new = line })
		end
	end
	return work.bonuses, changes
end

-- Writes the rolled lines and counts one attempt; the lock stays as it was.
function Reroll.applyAll(item: ItemInstance, bonuses: { Types.Bonus })
	local state = Reroll.state(item)
	item.bonuses = bonuses
	item.rr = if state.line then { i = state.line, n = state.n + 1 } else { n = state.n + 1 } :: any
end

-- Cost of the whole transformation with the scroll: Config.Reroll.allGoldMul times one attempt's gold, no essence.
function Reroll.costAll(item: ItemInstance): Cost
	return { gold = math.floor(Reroll.cost(item).gold * Config.Reroll.allGoldMul + 0.5), materials = {} }
end

-- The stats of the item's lines in order, joined (what the client saw: a changed item refuses the transformation).
function Reroll.signature(item: ItemInstance): string
	local parts: { string } = {}
	for _, line in (item.bonuses or {}) :: { any } do
		table.insert(parts, if type(line) == "table" and type(line.stat) == "string" then line.stat else "?")
	end
	return table.concat(parts, ",")
end

return Reroll
