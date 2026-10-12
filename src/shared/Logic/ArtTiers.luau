--!strict
-- Which real art an item uses (S52, docs/GRAFIKA.md 2): the owner draws models and icons per item tier (1, 5, 10,
-- 15, 20 for the first map). An item without its own takes the nearest LOWER tier of its type that has one, never
-- a higher one; without any it keeps today's look (Part look, SVG icon). A boss item's own model comes first. Pure:
-- the caller says what exists (`has`), so the rule runs in Lune.

local Items = require("../Data/Items")

local ArtTiers = {}

local TIERS: { number } = Items.bases.tiers

-- Highest listed item tier <= `tier` for which has(t) is true, or nil.
function ArtTiers.pick(tier: number?, has: (t: number) -> boolean): number?
	local limit = tier or 1
	for i = #TIERS, 1, -1 do
		local t = TIERS[i]
		if t <= limit and has(t) then
			return t
		end
	end
	return nil
end

-- Model id (WeaponLooks.assets key) for an item: its own entry (boss items, exact tiers), else "<type>_<t>" of the
-- nearest lower tier with a model, else nil (Part look).
function ArtTiers.modelId(def: { id: string, type: string, tier: number? }, has: (id: string) -> boolean): string?
	if has(def.id) then
		return def.id
	end
	local t = ArtTiers.pick(def.tier, function(t: number): boolean
		return has(`{def.type}_{t}`)
	end)
	return if t then `{def.type}_{t}` else nil
end

-- Icon keys of tier pictures for an atlas key, best first: "<base>@<t>" for every listed tier <= `tier`.
function ArtTiers.iconKeys(base: string, tier: number?): { string }
	local out = {}
	local limit = tier or 1
	for i = #TIERS, 1, -1 do
		if TIERS[i] <= limit then
			table.insert(out, `{base}@{TIERS[i]}`)
		end
	end
	return out
end

return ArtTiers
