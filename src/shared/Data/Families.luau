--!strict
-- Monster families (S66, docs/STATY.md 7). Data only. A kind (Data/Monsters) or a boss (Data/Bosses) names its
-- family; a kind may also name one defence trait of that family. Trait values live here (tuned in S84 / S88).

export type FamilyId = "animal" | "humanoid" | "undead" | "beast" | "elemental" | "dragon"
export type DefenceId = "armored" | "warded" | "scaled" | "agile"
export type Defence = { defMul: number?, mresMul: number?, dodge: number? }
export type FamilyDef = { id: FamilyId, nameKey: string, defences: { [string]: Defence } }

local ids: { FamilyId } = { "animal" :: FamilyId, "humanoid", "undead", "beast", "elemental", "dragon" }

local DEFENCES: { [string]: { [string]: Defence } } = {
	animal = { agile = { dodge = 12 } }, -- lynx, blood bat, snow leopard (STATY 7: 10-15 %)
	humanoid = { armored = { defMul = 1.6 } }, -- renegade dwarf, ash orc
	undead = { armored = { defMul = 1.8 }, warded = { mresMul = 1.8 } }, -- skeleton, knight / wraith, specter
	beast = { agile = { dodge = 15 } }, -- peak harpy
	elemental = { armored = { defMul = 2.0 } }, -- golems, crystal guardian
	dragon = { scaled = { defMul = 1.4, mresMul = 1.4 } }, -- every dragon
}

local byId: { [string]: FamilyDef } = {}
for _, id: FamilyId in ids do
	local defences: { [string]: Defence } = DEFENCES[id] or {}
	for _, trait: Defence in pairs(defences) do
		table.freeze(trait)
	end
	local def: FamilyDef = { id = id, nameKey = "family." .. id, defences = table.freeze(defences) }
	byId[id] = table.freeze(def)
end

return table.freeze({
	ids = table.freeze(ids),
	byId = table.freeze(byId),
	get = function(id: string): FamilyDef?
		return byId[id]
	end,
	-- The trait `defenceId` of family `familyId`, nil when either does not exist.
	defence = function(familyId: string, defenceId: string): Defence?
		local family = byId[familyId]
		return if family then family.defences[defenceId] else nil
	end,
})
