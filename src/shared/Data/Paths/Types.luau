--!strict
-- Class path shapes (ROZWOJ 3.2, S57). Rows and their level / point requirements come from Data/Paths ROWS through
-- Logic/Paths.rowsFor; the class files only fill the nodes. Shape example: tests/fixtures/paths.luau.

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
export type ReferenceBuild = {
	id: string,
	weapon: { main: string?, offhand: string? },
	nodes: { { any } }, -- { "nodeId", rank } in buying order
	bp: { [string]: string }?, -- "<skillId>:5" -> "a" | "b"
	stats: { [string]: number }?,
	rotation: { string }?,
	damageReference: number?,
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
	statPlan: { [string]: number }?, -- S58
	itemWeights: any?, -- S67; never on the wiki
	reference: { ReferenceBuild }, -- model builds; never on the wiki
	wiki: boolean?, -- false = unpublished on the wiki (ROZWOJ 3.5)
}
export type RowKind = "normal" | "choice" | "capstone" | "upgrade"
export type RowDef = { level: number, need: number, kind: RowKind, twoPathExtra: boolean? }

return nil
