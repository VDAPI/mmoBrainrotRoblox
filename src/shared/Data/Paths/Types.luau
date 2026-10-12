--!strict
-- Class path shapes (ROZWOJ 3.2, S57). Rows and their level / point requirements come from Data/Paths ROWS through
-- Logic/Paths.rowsFor; the class files only fill the nodes. Shape example: tests/fixtures/paths.luau.

local ItemWeights = require("../ItemWeights")
local SkillTypes = require("../Skills/Types")

export type Scaled = SkillTypes.Scaled -- { rank 1, rank max } or a constant, as in skills
export type WeaponReq = { main: { string }?, offhand: { string }? }
export type NodeKind = "skill" | "passive" | "modify" | "aura" | "luck" | "keystone"
export type PathNode = {
	id: string, -- unique in the game: "<pathId>_<name>"; a skill node is "<pathId>_<skillId>"
	kind: NodeKind,
	maxRank: number, -- 1..3 (skill and capstone 1, capstone upgrade 2)
	skill: string?, -- kind "skill": a skill with path == this path and unlock == the row level
	values: { [string]: Scaled }?, -- numbers that depend on the node rank
	passive: { flat: { [string]: string }?, pct: { [string]: string }?, hooks: { [string]: string }? }?,
	-- option: works only while that option is chosen at rank `at` (default 5) of the target skill. Every number in
	-- `bp` that depends on the node rank is { ref = "<values field>" } (Logic/Paths.skillMods resolves it).
	modify: { skill: string, option: ("a" | "b")?, at: number?, bp: any }?,
	-- S61: a party aura (PartyAuraService). category = a Data/BuffCategories ally* id. For categories with stats
	-- (allyAttack, allyHaste, allyCrit, allyMove, allyVigor) the keys of `stats` are the category's stats (stat -> values
	-- field); for a value category (allyGuard) `stats` holds exactly one key, `value`, e.g. the Guardian's cover:
	-- { category = "allyGuard", stats = { value = "cover" }, radius = 15, shape = "behind" }. Radius default: AURA.radius
	-- for circle, AURA.behindRadius for behind.
	aura: { category: string, stats: { [string]: string }, radius: number?, shape: ("circle" | "behind")? }?,
	luck: { [string]: string }?, -- Data/Luck field -> values field (S60)
	weapon: WeaponReq?, -- own requirement, valid in every row
	dipScale: number?, -- team effect strength in rows 1..DIP_ROWS outside the main path (default DIP_SCALE)
	extra: boolean?, -- the twoPathExtra node of rows 2, 5, 10 (last in its row)
	glyph: string,
	nameKey: string, -- path.<pathId>.<name>.name (skill nodes: the skill's own keys)
	descKey: string,
}
export type PathRow = { choice: boolean, nodes: { PathNode } }
-- S71 (ROZWOJ 3.2, 7.5): a model build, the shape every class copies; read by tests and the balance model (S85), never
-- by the game or the wiki. Rotation entries: `skill` (required) plus optional conditions, data only:
-- target = "tank" | "mostWounded" | "meleeAllies" | "self" | "allyInZone" (an ally in a red zone, S75), minWounded,
-- minEnemies, belowHp, debuff, beforeRedZone, opener, elite, minFury (at least that many Fury stacks, S75), notInZone
-- (only while the character stands outside red zones, S78), minCharges (Arcane Charge stacks), minManaPct and
-- maxManaPct (% of maximum mana; S81 Mage).
export type ReferenceBuild = {
	id: string,
	damageReference: boolean?, -- only the Berserker "fury" build (S75)
	r7Exempt: boolean?, -- S78 (ROZWOJ 15.4.2): exempt from R7 on one target (Trapper); read by the balance model
	-- S81 (ROZWOJ 8, 15.5.3): area / single target burst cap of this build (R3 / T-SK3); nil = 2.0. Read by the
	-- balance model (S86, S90), never by the game.
	areaCap: number?,
	weapon: { main: string, offhand: string? },
	-- { nodeId, rank } in purchase order: by row level, main path first at the same level (S71-S78); the Mage (S81)
	-- lists them in the priority order of ROZWOJ 12.4 / 12.5 (the 12.7 measurement buys them in that order)
	nodes: { { any } },
	bp: { [string]: "a" | "b" }, -- "<skillId>:5" / "<skillId>:10"; a missing entry means A
	stats: { [string]: number }, -- the path statPlan
	rotation: { { [string]: any } }, -- priority list, first usable wins; conditions are data for the balance model (S85)
}
export type Role = "damage" | "tank" | "healer" | "support" | "luck"
export type PathDef = {
	id: string,
	class: string,
	order: number,
	role: Role,
	nameKey: string, -- path.<pathId>.name
	descKey: string, -- path.<pathId>.desc
	titleId: string, -- path_<pathId> (the title itself comes in S59)
	weapon: WeaponReq,
	rows: { PathRow }, -- 11; level and point requirement come from Paths.rowsFor
	-- S58: plan of the path as main path; the class plan applies without one; never on the wiki
	statPlan: { [string]: number }?,
	itemWeights: ItemWeights.ItemWeights?, -- S67: multipliers on the class weights of Logic/ItemScore; never on the wiki
	reference: { ReferenceBuild }, -- model builds; never on the wiki
	wiki: boolean?, -- false = unpublished on the wiki (ROZWOJ 3.5)
}
export type RowKind = "normal" | "choice" | "capstone" | "upgrade"
export type RowDef = { level: number, need: number, kind: RowKind, twoPathExtra: boolean? }

return nil
