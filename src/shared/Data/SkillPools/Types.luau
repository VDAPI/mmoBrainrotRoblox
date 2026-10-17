--!strict
-- Shapes of the weapon pools (S137, DESIGN-18 §4, §9).

-- The weapon that selects a pool: main-hand base types (Data/Items/Bases) and, for the Mage, the weapon element.
export type PoolWeapon = { main: { string }, element: string? }

export type PoolDef = {
	id: string,
	nameKey: string, -- skills.pool.<id>
	glyph: string,
	weapon: PoolWeapon,
	-- every base skill of the pool (its school and the class's common skills) in buying order: actives by unlock, then
	-- passives by unlock ("Spend as the pool suggests", the migration)
	plan: { string },
}

export type ClassPools = {
	-- bumped by a class session that changes the pools: on load the ranks are cleaned and a free reset is given
	-- (Logic/SkillPoints.needsRespec), no migration (DESIGN-18 §10)
	version: number,
	-- the ladder of DESIGN-18 §5 does not hold yet (S137: the old base split into pools; S140-S145 end it)
	transitional: boolean?,
	defaultPool: string, -- no weapon or an unknown one
	pools: { PoolDef },
	commonPlan: { string }, -- the common skills of the class in buying order
}

-- One rung of the shared ladder: the role code and its unlock level.
export type Rung = { code: string, level: number, passive: boolean? }

return nil
