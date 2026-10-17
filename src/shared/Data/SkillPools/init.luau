--!strict
-- Weapon pools of every class (S137, DESIGN-18 §4, §5, §9): the equipped weapon selects the pool, each pool has its
-- own skill points, ranks and 8-slot bar. LADDER / COMMON_LADDER = the shared ladder (the same role unlocks at the
-- same level in every pool of every class); a class with `transitional` does not follow it yet (tests/skillpools.spec).
-- Rules: Logic/SkillPools, Logic/SkillPoints.

local Cleric = require("@self/Cleric")
local Hunter = require("@self/Hunter")
local Mage = require("@self/Mage")
local Types = require("@self/Types")
local Warrior = require("@self/Warrior")

export type PoolDef = Types.PoolDef
export type PoolWeapon = Types.PoolWeapon
export type ClassPools = Types.ClassPools
export type Rung = Types.Rung

-- The school of every pool: 9 actives and 2 passives (DESIGN-18 §5).
local LADDER: { Rung } = {
	{ code = "S1", level = 1 },
	{ code = "A1", level = 3 },
	{ code = "K1", level = 6 },
	{ code = "O1", level = 10 },
	{ code = "S2", level = 15 },
	{ code = "P1", level = 20, passive = true },
	{ code = "A2", level = 26 },
	{ code = "K2", level = 33 },
	{ code = "S3", level = 40 },
	{ code = "P2", level = 50, passive = true },
	{ code = "U", level = 60 },
}

-- The common skills of a class, in every pool of it (DESIGN-18 §5).
local COMMON_LADDER: { Rung } = {
	{ code = "C1", level = 4 },
	{ code = "C2", level = 12 },
	{ code = "C3", level = 30 },
	{ code = "C4", level = 45, passive = true },
}

local byClass: { [string]: ClassPools } = {
	Warrior = Warrior,
	Hunter = Hunter,
	Mage = Mage,
	Cleric = Cleric,
}

return table.freeze({
	LADDER = table.freeze(LADDER),
	COMMON_LADDER = table.freeze(COMMON_LADDER),
	COMMON = "common", -- SkillDef.pool of a common skill
	byClass = byClass,
	get = function(classId: string): ClassPools?
		return byClass[classId]
	end,
})
